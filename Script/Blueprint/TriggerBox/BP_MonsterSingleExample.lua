---@class BP_MonsterSingleExample_C:BP_MonsterExampleBase_C
---@field Widget1 UWidgetComponent
---@field StaticMesh3 UStaticMeshComponent
---@field StaticMesh2 UStaticMeshComponent
---@field StaticMesh1_0 UStaticMeshComponent
---@field Cube1 UStaticMeshComponent
---@field PointSceneComp PointSceneComp_C
--Edit Below--
local BP_MonsterSingleExample = {}

function BP_MonsterSingleExample:CheckCanActive(ClickParam)
    print("MonsterSingleExample:CheckCanActive")
    return true;
end

function BP_MonsterSingleExample:SpawnMonster()
    print("SpawnMonsterRangeSpawnMobsStart")
    if self:HasAuthority() then
        self:StartSpawnerManager()
        print("SpawnMonsterRangeSpawnMobs")
    end
    
end

function BP_MonsterSingleExample:DeathMonster()
    print("SpawnMonsterTakeDamageStart")
    if self:HasAuthority() then
        if self.AliveMobs and #self.AliveMobs > 0 then
            -- 使用 KillGenericCharacter 
            for k, v in pairs(self.AliveMobs) do
                UGCGenericCharacterSystem.KillGenericCharacter(v)
            end
            print("SpawnMonsterTakeDamage")
        else
            print("No valid monster to damage")
        end
        self:ResetSpawnerManager(false)
    end
end

function BP_MonsterSingleExample:ReceiveBeginPlay()
    BP_MonsterSingleExample.SuperClass.ReceiveBeginPlay(self)
    -- print("BP_MonsterSingleExample  WidgetTitle  " .. tostring(self.Des))
    -- self.Widget1.Widget.TextBlock_Title:SetText(self.Des)
end

function BP_MonsterSingleExample:OnAllMobDie()
    print("BP_MonsterSingleExample  OnAllMobDie")
    self:ResetSpawnerManager(false)
end

return BP_MonsterSingleExample
