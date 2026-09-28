"""One-time BT_Boss route repair for the custom UGC UE4.18 editor.

Run through UGC MCP ue_py only after submitting a PRV plan for BT_Boss. Make a
source .uasset backup first. Default mode edits the original asset when run;
pass BT_ROUTE_MODE='precheck' in the exec globals for read-only old-state
validation, or BT_ROUTE_MODE='verify' after a disk reload for read-only target
validation. Default mode is deliberately safe to run again after a fresh disk
reload, where it reports ALREADY_CORRECT without saving. Any intermediate or
manual state is rejected.

The single BossUpdateContext service belongs to ungated BossPriority. Putting
the only target-acquisition service below CombatActive can deadlock acquisition.
After execution, unload/reload BT_Boss in Editor and run this script again for
disk readback. Then SavePackage with SAVEFORMAT=LinuxServer and inspect its
import/export tables before a DS LoadObject and runtime test.
"""

import re
import unreal_engine as ue
from unreal_engine.classes import BehaviorTree


ASSET = "/TTS/Asset/AI/BT/BT_Boss.BT_Boss"
BOOL_BRANCHES = (
    ("BossDeathTask", ("IsDead", 0)),
    ("BossReturnHomeTask", ("MustReset", 0)),
    ("BossHardStaggerTask", ("CanApplyHardStagger", 0)),
    ("BossPhaseTransitionTask", ("PhaseTransitionReady", 0)),
    ("Combat", ("CombatActive", 0)),
)
ACTION_BRANCHES = (
    ("BossGiveSpaceTask", ("ActionKind", 4)),
    ("BossSearchTask", ("ActionKind", 5)),
    ("SkillRouter", ("ActionKind", 1)),
    ("BossChaseSliceTask", ("ActionKind", 2)),
    ("BossRepositionTask", ("ActionKind", 3)),
)
SKILL_BRANCHES = tuple(
    ("BossExecuteSkillTask%d" % i, ("SelectedSkill", i))
    for i in range(1, 8)
)
ALL_BRANCHES = BOOL_BRANCHES + ACTION_BRANCHES + SKILL_BRANCHES
BRANCH_KEY = dict(ALL_BRANCHES)

OLD_CHILDREN = {
    "__root__": ("Combat",),
    "Combat": (
        "OneDecision", "WaitCombat", "BossDeathTask", "BossReturnHomeTask",
        "BossHardStaggerTask", "BossPhaseTransitionTask", "Idle",
    ),
    "OneDecision": ("BossPlanNextActionTask", "ActionRouter"),
    "ActionRouter": (
        "BossGiveSpaceTask", "BossSearchTask", "SkillRouter",
        "BossChaseSliceTask", "BossRepositionTask",
    ),
    "SkillRouter": tuple("BossExecuteSkillTask%d" % i for i in range(1, 8)),
    "Idle": ("BossSetIdleStateTask", "WaitIdle"),
}
NEW_CHILDREN = {
    "__root__": ("BossPriority",),
    "BossPriority": (
        "BossDeathTask", "BossReturnHomeTask", "BossHardStaggerTask",
        "BossPhaseTransitionTask", "Combat", "Idle",
    ),
    "Combat": ("OneDecision", "WaitCombat"),
    "OneDecision": ("BossPlanNextActionTask", "ActionRouter"),
    "ActionRouter": OLD_CHILDREN["ActionRouter"],
    "SkillRouter": OLD_CHILDREN["SkillRouter"],
    "Idle": OLD_CHILDREN["Idle"],
}


def check(condition, message):
    if not condition:
        raise RuntimeError(message)


def path(obj):
    return obj.get_path_name() if obj else None


def runtime_nodes(bt):
    result = {}
    for graph_node in bt.BTGraph.Nodes:
        instance = getattr(graph_node, "NodeInstance", None)
        if not instance:
            continue
        name = instance.NodeName
        check(name and name not in result, "Duplicate/missing runtime NodeName: %r" % name)
        result[name] = (graph_node, instance)
    return result


def auxiliary_nodes(bt):
    decorators = {}
    services = []
    for owner in bt.BTGraph.Nodes:
        for graph_node in getattr(owner, "Decorators", []):
            instance = graph_node.NodeInstance
            check(instance is not None, "Decorator graph node lacks NodeInstance")
            key = (instance.BlackboardKey.SelectedKeyName, int(instance.IntValue))
            check(key not in decorators, "Duplicate decorator key: %r" % (key,))
            decorators[key] = (graph_node, instance, owner)
        for graph_node in getattr(owner, "Services", []):
            check(graph_node.NodeInstance is not None, "Service graph node lacks NodeInstance")
            services.append((graph_node, graph_node.NodeInstance, owner))
    return decorators, services


def graph_children(bt):
    """Parse the public bt_query outline; pins are not exposed by this UE Python."""
    outline = ue.bt_query(bt)
    result = {}
    stack = [(-1, "__root__")]
    for line in outline.splitlines():
        match = re.match(r"^(\s*)\[(?:Composite|Task)\]\s+([^\s(]+)", line)
        if not match:
            continue
        depth, name = len(match.group(1)), match.group(2)
        while stack[-1][0] >= depth:
            stack.pop()
        parent = stack[-1][1]
        result.setdefault(parent, []).append(name)
        stack.append((depth, name))
    return {key: tuple(value) for key, value in result.items()}, outline


def check_graph(bt, expected, count):
    children, outline = graph_children(bt)
    check(children == expected, "Graph routes differ. Actual: %r" % children)
    summary = "[Total: %d nodes, %d connected, 0 orphan]" % (count, count)
    check(summary in outline, "Graph has disconnected/orphan nodes: %s" % outline[-200:])


def check_common(bt, expected_main_count):
    check(bt is not None and bt.BTGraph is not None and bt.RootNode is not None,
          "BT_Boss/BTGraph/RootNode failed to load")
    check("BB_Boss" in path(bt.BlackboardAsset), "Unexpected blackboard")
    nodes = runtime_nodes(bt)
    decorators, services = auxiliary_nodes(bt)
    check(len(bt.BTGraph.Nodes) == expected_main_count,
          "Unexpected main graph-node count")
    check(len(nodes) == expected_main_count - 1, "Unexpected runtime main-node count")
    check(set(decorators) == set(BRANCH_KEY.values()),
          "Decorator keys changed; refusing to overwrite manual edits")
    check(len(services) == 1, "Expected one BossUpdateContext service")
    all_graph = list(bt.BTGraph.Nodes)
    all_graph += [item[0] for item in decorators.values()]
    all_graph += [services[0][0]]
    check(len({path(item) for item in all_graph}) == expected_main_count + 18,
          "Graph-node identity/count changed")
    check(all((item.get_obj_flags() & 0xF) == 0x8 for item in all_graph),
          "Graph flags are not normalized to low nibble 0x8")
    all_runtime = [item[1] for item in nodes.values()]
    all_runtime += [item[1] for item in decorators.values()]
    all_runtime += [services[0][1]]
    check(all(item.get_outer() == bt and not (item.get_obj_flags() & 0x40)
              and item.TreeAsset == bt for item in all_runtime),
          "Runtime node is not asset-owned, or is Transient")
    return nodes, decorators, services[0]


def parent_by_child(children):
    parents = {}
    for parent, names in children.items():
        if parent == "__root__":
            continue
        for name in names:
            check(name not in parents, "Child occurs on two runtime branches: " + name)
            parents[name] = parent
    return parents


def check_prestate(bt):
    nodes, decorators, service = check_common(bt, 25)
    check(set(nodes) == set(parent_by_child(OLD_CHILDREN)) | {"Combat"},
          "Original runtime nodes changed")
    check(bt.RootNode == nodes["Combat"][1], "Expected Combat as old root")
    check_graph(bt, OLD_CHILDREN, 25)
    expected_graph_owner = {}
    for _, key in BOOL_BRANCHES:
        expected_graph_owner[key] = "Combat"
    for _, key in ACTION_BRANCHES:
        expected_graph_owner[key] = "ActionRouter"
    for _, key in SKILL_BRANCHES:
        expected_graph_owner[key] = "SkillRouter"
    for key, (aux_graph, _, owner) in decorators.items():
        check(owner == nodes[expected_graph_owner[key]][0]
              and aux_graph.ParentNode == owner,
              "Old decorator graph location changed: %r" % (key,))
    check(service[2] == nodes["Combat"][0], "Old service owner changed")
    check(all(len(item.SubNodes) == 0 for item in bt.BTGraph.Nodes),
          "Unexpected pre-existing SubNodes; manual graph edit detected")
    expected_root = [decorators[key][1] for _, key in BOOL_BRANCHES]
    check([path(item) for item in bt.RootDecorators] ==
          [path(item) for item in expected_root], "RootDecorators changed")
    check(len(bt.RootDecoratorOps) == 0, "Unexpected RootDecoratorOps")
    old_parents = parent_by_child(OLD_CHILDREN)
    for name, (graph_node, instance) in nodes.items():
        expected_parent = (nodes[old_parents[name]][1]
                           if name in old_parents else None)
        check(instance.ParentNode == expected_parent,
              "Old runtime ParentNode changed: " + name)
        if name not in OLD_CHILDREN:
            continue
        children = instance.Children
        check(len(children) == len(OLD_CHILDREN[name]),
              "Old runtime child count changed: " + name)
        for expected_name, edge in zip(OLD_CHILDREN[name], children):
            child = edge.ChildComposite or edge.ChildTask
            check(child == nodes[expected_name][1],
                  "Old runtime child order changed: " + name)
            expected = []
            if name == "OneDecision" and expected_name == "ActionRouter":
                expected = [decorators[key][1] for _, key in ACTION_BRANCHES]
            if name == "ActionRouter" and expected_name == "SkillRouter":
                expected = [decorators[key][1] for _, key in SKILL_BRANCHES]
            check([path(item) for item in edge.Decorators] ==
                  [path(item) for item in expected],
                  "Old runtime edge decorators changed: " + expected_name)
        expected_service = [service[1]] if name == "Combat" else []
        check([path(item) for item in instance.Services] ==
              [path(item) for item in expected_service],
              "Old runtime service placement changed: " + name)
    return nodes, decorators, service


def check_target(bt):
    nodes, decorators, service = check_common(bt, 26)
    check(set(nodes) == set(parent_by_child(NEW_CHILDREN)) | {"BossPriority"},
          "Target runtime nodes changed")
    check(bt.RootNode == nodes["BossPriority"][1],
          "BossPriority is not runtime RootNode")
    check_graph(bt, NEW_CHILDREN, 26)
    check(len(bt.RootDecorators) == 0 and len(bt.RootDecoratorOps) == 0,
          "Old root decorators remain")
    parents = parent_by_child(NEW_CHILDREN)
    for name, (graph_node, instance) in nodes.items():
        expected_parent = nodes[parents[name]][1] if name in parents else None
        check(instance.ParentNode == expected_parent,
              "Target runtime ParentNode differs: " + name)
        expected_service = [service[1]] if name == "BossPriority" else []
        if name in NEW_CHILDREN:
            check([path(item) for item in instance.Services] ==
                  [path(item) for item in expected_service],
                  "Target runtime service differs: " + name)
            children = instance.Children
            check(len(children) == len(NEW_CHILDREN[name]),
                  "Target child count differs: " + name)
            for expected_name, edge in zip(NEW_CHILDREN[name], children):
                child = edge.ChildComposite or edge.ChildTask
                check(child == nodes[expected_name][1],
                      "Target child order differs: " + name)
                expected = ([decorators[BRANCH_KEY[expected_name]][1]]
                            if expected_name in BRANCH_KEY else [])
                check([path(item) for item in edge.Decorators] ==
                      [path(item) for item in expected],
                      "Target runtime edge decorator differs: " + expected_name)
                check(len(edge.DecoratorOps) == 0,
                      "Unexpected target DecoratorOps on " + expected_name)
    for child_name, key in ALL_BRANCHES:
        aux_graph, aux_runtime, owner = decorators[key]
        expected_owner = nodes[child_name][0]
        check(owner == expected_owner and aux_graph.ParentNode == expected_owner,
              "Target graph decorator owner differs: " + child_name)
        check([path(item) for item in expected_owner.Decorators] == [path(aux_graph)]
              and [path(item) for item in expected_owner.SubNodes] == [path(aux_graph)],
              "Target graph Decorators/SubNodes differ: " + child_name)
        check(aux_runtime.ParentNode == nodes[parents[child_name]][1],
              "Target runtime decorator ParentNode differs: " + child_name)
    for name, (graph_node, _) in nodes.items():
        if name not in BRANCH_KEY:
            check(len(graph_node.Decorators) == 0,
                  "Unexpected graph decorator on " + name)
    priority_graph = nodes["BossPriority"][0]
    check(service[2] == priority_graph and service[0].ParentNode == priority_graph,
          "Service graph owner is not BossPriority")
    check([path(item) for item in priority_graph.Services] == [path(service[0])]
          and [path(item) for item in priority_graph.SubNodes] == [path(service[0])],
          "Service graph Services/SubNodes differ")
    check(service[1].ParentNode == nodes["BossPriority"][1],
          "Service runtime ParentNode is not BossPriority")
    for name, (graph_node, _) in nodes.items():
        if name != "BossPriority":
            check(len(graph_node.Services) == 0,
                  "Unexpected service on " + name)
        if name not in BRANCH_KEY and name != "BossPriority":
            check(len(graph_node.SubNodes) == 0,
                  "Unexpected graph SubNodes on " + name)
    return nodes, decorators, service


def route_repair(bt, old_nodes, decorators, service):
    old_runtime = {name: pair[1] for name, pair in old_nodes.items()}
    old_edges = {}
    for name, instance in old_runtime.items():
        if name not in OLD_CHILDREN:
            continue
        for edge in instance.Children:
            child = edge.ChildComposite or edge.ChildTask
            check(child is not None and child.NodeName not in old_edges,
                  "Cannot snapshot FBTCompositeChild for " + name)
            old_edges[child.NodeName] = edge.clone()
    check(set(old_edges) == set(old_runtime) - {"Combat"},
          "Runtime edge template inventory changed")
    root_graph = [item for item in bt.BTGraph.Nodes
                  if item.get_class().get_name() == "UGCBehaviorTreeGraphNode_Root"]
    check(len(root_graph) == 1, "Expected one graph Root node")
    root_graph_name = root_graph[0].get_name()

    # Graph topology first. These APIs can rebuild runtime arrays; all runtime
    # references above are snapshotted and are restored below before saving.
    ue.bt_add_node(bt, "Selector", "BossPriority")
    ue.bt_unlink(bt, root_graph_name, "Combat")
    try:
        ue.bt_link(bt, root_graph_name, "BossPriority")
    except Exception as exc:
        message = str(exc).lower()
        if "already connected" not in message and "已连接" not in message:
            raise
    for child_name in (
        "BossDeathTask", "BossReturnHomeTask", "BossHardStaggerTask",
        "BossPhaseTransitionTask", "Idle",
    ):
        ue.bt_unlink(bt, "Combat", child_name)
        ue.bt_link(bt, "BossPriority", child_name)
    ue.bt_link(bt, "BossPriority", "Combat")
    ue.bt_reorder(bt, "BossPriority", list(NEW_CHILDREN["BossPriority"]))
    check_graph(bt, NEW_CHILDREN, 26)

    graph_nodes = runtime_nodes(bt)
    check(set(graph_nodes) == set(old_runtime) | {"BossPriority"},
          "Graph edit replaced or renamed a runtime node")
    priority_graph = graph_nodes["BossPriority"][0]
    priority_generated = graph_nodes["BossPriority"][1]
    priority = ue.new_object(priority_generated.get_class(), bt)
    priority.NodeName = "BossPriority"
    priority.TreeAsset = bt
    priority.ParentNode = None
    old_runtime["BossPriority"] = priority
    # The graph API's temporary runtime template will become unreferenced.
    # Ensure it cannot remain a public export that retains its editor-only Outer.
    if priority_generated.get_obj_flags() & 0x1:
        priority_generated.clear_obj_flags(0x1)
    if not (priority_generated.get_obj_flags() & 0x8):
        priority_generated.set_obj_flags(0x8)

    # Keep every pre-existing asset-owned runtime object, even if a bt_* graph
    # operation transiently regenerated a NodeInstance.
    for name, (graph_node, _) in graph_nodes.items():
        graph_node.NodeInstance = old_runtime[name]

    # Restore each auxiliary graph node and put it on the child whose incoming
    # edge carries its condition. Healthy UI trees also list it in SubNodes.
    for graph_node in bt.BTGraph.Nodes:
        graph_node.Decorators = []
        graph_node.Services = []
        graph_node.SubNodes = []
    for child_name, key in ALL_BRANCHES:
        owner = graph_nodes[child_name][0]
        aux_graph, aux_runtime, _ = decorators[key]
        owner.Decorators = [aux_graph]
        owner.SubNodes = [aux_graph]
        aux_graph.ParentNode = owner
        aux_graph.NodeInstance = aux_runtime
    service_graph, service_runtime, _ = service
    priority_graph.Services = [service_graph]
    priority_graph.SubNodes = [service_graph]
    service_graph.ParentNode = priority_graph
    service_graph.NodeInstance = service_runtime

    def make_edge(child_name):
        source = old_edges.get(child_name, old_edges["OneDecision"])
        edge = source.clone()
        child = old_runtime[child_name]
        composite = child.get_class().get_name().startswith("BTComposite_")
        edge.ChildComposite = child if composite else None
        edge.ChildTask = None if composite else child
        edge.Decorators = ([decorators[BRANCH_KEY[child_name]][1]]
                           if child_name in BRANCH_KEY else [])
        edge.DecoratorOps = []
        return edge

    for parent_name, child_names in NEW_CHILDREN.items():
        if parent_name == "__root__":
            continue
        parent = old_runtime[parent_name]
        parent.Children = [make_edge(child_name) for child_name in child_names]
        parent.Services = [service_runtime] if parent_name == "BossPriority" else []
    parents = parent_by_child(NEW_CHILDREN)
    for name, instance in old_runtime.items():
        instance.ParentNode = (old_runtime[parents[name]] if name in parents else None)
    for child_name, key in ALL_BRANCHES:
        decorators[key][1].ParentNode = old_runtime[parents[child_name]]
    service_runtime.ParentNode = priority
    bt.RootDecorators = []
    bt.RootDecoratorOps = []
    bt.RootNode = priority

    # bt_add_node uses a graph-owned runtime template and may set non-editor
    # graph flags. Normalize all graph objects to the proven Mage pattern.
    all_graph = list(bt.BTGraph.Nodes)
    all_graph += [item[0] for item in decorators.values()]
    all_graph += [service_graph]
    for graph_node in all_graph:
        if graph_node.get_obj_flags() & 0x1:
            graph_node.clear_obj_flags(0x1)
        if not (graph_node.get_obj_flags() & 0x8):
            graph_node.set_obj_flags(0x8)
    check_target(bt)
    bt.save_package()
    check_target(bt)  # In-memory post-save; unload/reload separately for disk proof.
    print("ROUTE_REPAIR_SAVED", ASSET, len(bt.BTGraph.Nodes), ue.bt_query(bt))


bt = ue.load_object(BehaviorTree, ASSET)
check(bt is not None, "BT_Boss cannot be loaded")
mode = globals().get("BT_ROUTE_MODE", "apply")
if mode == "precheck":
    check_prestate(bt)
    print("PRECHECK_OK", ASSET, "No save or asset mutation")
elif mode == "verify":
    check_target(bt)
    print("VERIFY_OK", ASSET, "No save or asset mutation")
elif mode == "apply":
    try:
        check_target(bt)
    except RuntimeError as target_error:
        try:
            old_nodes, old_decorators, old_service = check_prestate(bt)
        except RuntimeError as pre_error:
            raise RuntimeError(
                "Refusing to edit BT_Boss: neither clean target nor exact pre-route state. "
                "Target: %s; Pre-route: %s" % (target_error, pre_error)
            )
        route_repair(bt, old_nodes, old_decorators, old_service)
    else:
        print("ALREADY_CORRECT", ASSET, "No save or asset mutation")
else:
    raise RuntimeError("Unknown BT_ROUTE_MODE: %r" % mode)
