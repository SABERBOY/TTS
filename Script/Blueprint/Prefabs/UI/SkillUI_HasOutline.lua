local SkillUI_HasOutline = {
	ReadyForActivateTimer = nil,
	PreCDState = false,
	PreEnableState = false,
	PreTagDisableState = false,
}

function SkillUI_HasOutline:Construct()
	SkillUI_HasOutline.SuperClass.InitButton(self, self.Image_Icon, self.Text_Name, self.Button_Skill)
	SkillUI_HasOutline.SuperClass.InitCDProgress(self, self.Text_Time, self.Image_CDTime, self.CanvasPanel_CDtime)
	SkillUI_HasOutline.SuperClass.InitEnergyProgress(self, self.Image_ChargingCD, self.CanvasPanel_Charging)
	SkillUI_HasOutline.SuperClass.InitLayer(self, self.Text_Num, self.CanvasPanel_Number)
	SkillUI_HasOutline.SuperClass.InitEnableState(self, self.CanvasPanel_Lock)
	SkillUI_HasOutline.SuperClass.InitTagDisableState(self, self.CanvasPanel_Disable)
	
	self.CanvasPanel_OneAvailable:SetVisibility(ESlateVisibility.Collapsed)
	self.CanvasPanel_ComboTime:SetVisibility(ESlateVisibility.Collapsed)
end

function SkillUI_HasOutline:EnableComboInputComp()
	self.CanvasPanel_ComboTime:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
end

function SkillUI_HasOutline:DisableComboComp()
	self.CanvasPanel_ComboTime:SetVisibility(ESlateVisibility.Collapsed)
end

function SkillUI_HasOutline:SetComboInputProgress(progress)
	self.Image_ComboTime:GetDynamicMaterial():SetScalarParameterValue("Mask_Percent", progress)
end

function SkillUI_HasOutline:UpdateCD_BP(Delta)
	SkillUI_HasOutline.SuperClass.UpdateCD_BP(self, Delta)
	local Skill = self:GetCurrentSkill()
	if Skill.IsShowComboTime then
		self:EnableComboInputComp()
		self:SetComboInputProgress(Skill.ComboInputProgress)
	else
		self:DisableComboComp()
	end
end


function SkillUI_HasOutline:OnSkillBound_BP(InOwnerSkill)
	SkillUI_HasOutline.SuperClass.OnSkillBound_BP(self, InOwnerSkill)

    if UE.IsValid(InOwnerSkill) then
        self.PreCDState = InOwnerSkill.SkillCD.MaxLayer ~= InOwnerSkill.SkillCD.CurLayer
        self.PreEnableState = InOwnerSkill:IsSkillEnable()
    end
end

function SkillUI_HasOutline:OnCDStateChange_BP(IsCD)
	local Skill = self:GetCurrentSkill()
	if not Skill then
		return
	end

	-- play effect
	if not IsCD and self.PreCDState ~= IsCD then
		self.CanvasPanel_OneAvailable:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
		self:PlayAnimation(self.DX_RefreshSkill, 0, 1, EUMGSequencePlayMode.Forward, 1)
		if self.ReadyForActivateTimer then
			Timer.RemoveTimer(self.ReadyForActivateTimer)
		end
		self.ReadyForActivateTimer = Timer.InsertTimer(1, function()
			if self and UE.IsValid(self) then
				self.CanvasPanel_OneAvailable:SetVisibility(ESlateVisibility.Collapsed)
				self.ReadyForActivateTimer = nil
			end
		end, false)
	end

	self.PreCDState = IsCD
	SkillUI_HasOutline.SuperClass.OnCDStateChange_BP(self, IsCD)
end 

function SkillUI_HasOutline:OnEnableChange_BP(IsEnable)
	SkillUI_HasOutline.SuperClass.OnEnableChange_BP(self, IsEnable)
	if IsEnable and self.PreEnableState ~= IsEnable then
		self:PlayAnimation(self.DX_UpgradeSkills, 0, 1, EUMGSequencePlayMode.Forward, 1)
	end
	self.PreEnableState = IsEnable
end

function SkillUI_HasOutline:OnTagDisableChange_BP(IsDisable)
	SkillUI_HasOutline.SuperClass.OnTagDisableChange_BP(self, IsDisable)
	if not IsDisable and self.PreTagDisableState ~= IsDisable then
		self:PlayAnimation(self.DX_UpgradeSkills_old, 0, 1, EUMGSequencePlayMode.Forward, 1)
	end
	self.PreTagDisableState = IsDisable
end


return SkillUI_HasOutline