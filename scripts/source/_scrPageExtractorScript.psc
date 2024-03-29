Scriptname _scrPageExtractorScript extends ObjectReference  

_scrProgressionScript Property ProgressScript Auto
_scrWorkstationManagerScript Property WorkstationScript Auto

ObjectReference Property TempStorage  Auto  

GlobalVariable Property InscriptionLevel Auto
Quest Property TutorialQuest  Auto  
MiscObject Property ArcaneDust Auto
MiscObject Property RollOfPaper Auto

Perk Property DisenchantPerk  Auto  

FormList Property SoulGemList Auto
FormList Property FilledSoulGemList  Auto 
GlobalVariable Property DustPerGemRank Auto 

; Animation
Idle Property IdleStart Auto
Idle Property IdleStop Auto

Static Property StickyMarker Auto
ObjectReference StickyMarkerRef
Activator Property MarkerEffectSummon Auto
Activator Property MarkerEffectBanish Auto
VisualEffect Property MarkerEffectWait Auto
VisualEffect Property MarkerEffectDestroyItem Auto
Sound Property ExtractSFX Auto

Actor ThisActor
ObjectReference[] DroppedDustList
int DroppedDustListIndex = 0
int MAX_DROPS = 32

float SpawnAngleZ
float LocalAngleX
float LocalAngleY

Event OnActivate(ObjectReference akActionRef)
	if akActionRef != Game.GetPlayer()
		return
	endif

	ThisActor = akActionRef as Actor
	WorkstationScript.IsBusy = true
	; wait for player to leave menu
	Utility.WaitMenuMode(2.5)
	while !Game.IsLookingControlsEnabled() || !Game.IsMovementControlsEnabled() || UI.IsMenuOpen("ContainerMenu") 
		Utility.Wait(0.25)
	EndWhile
	RegisterForSingleUpdate(0.1)
EndEvent

Event OnUpdate()
	int itemCount = self.GetNumItems()
	if itemCount == 0
		ClearDroppedItems()
		ThisActor.PlayIdle(IdleStop)
		MarkerEffectWait.Stop(WorkstationScript.SummonedBenchExtract)
		WorkstationScript.IsBusy = false
		return
	endif

	Self.BlockActivation(abBlocked = True)
	itemCount = self.GetNumItems() ; just in case
	ThisActor.PlayIdle(IdleStart)
	
	if !DroppedDustList
		SpawnAngleZ = WorkstationScript.SummonedBenchExtract.GetAngleZ() + 180
		LocalAngleX = 45 * Math.Cos(SpawnAngleZ)
		LocalAngleY = -45 * Math.Sin(SpawnAngleZ)
		
		DroppedDustList = new ObjectReference[32] ; MAX_DROPS
		StickyMarkerRef = ThisActor.PlaceAtMe(StickyMarker,1,FALSE,false)
		
		; weird workaround for physics sometimes not working - i don't know
		float stickyZ = WorkstationScript.SummonedBenchExtract.Z - 1000.0
		if stickyZ < - 4000.0
			stickyZ *= -0.5
		endif
		StickyMarkerRef.SetPosition(WorkstationScript.SummonedBenchExtract.X, WorkstationScript.SummonedBenchExtract.Y, stickyZ)
		Utility.Wait(0.1)
		MarkerEffectWait.Play(WorkstationScript.SummonedBenchExtract)
	endif

	int i = 0
	while i < itemCount
		Form theForm = self.GetNthForm(i)
		if theForm as Book && (theForm as Book).GetSpell()
			Book itm = theForm as Book
			Scroll product = ScrollScribeExtender.GetScrollForBook(itm)
			if product
				int count = self.GetItemCount(itm)
				int level = InscriptionLevel.GetValueInt()
				int finalCount = count * (15 + Math.Ceiling( 0.5 * level ))
				TempStorage.AddItem(product, finalCount)
				self.RemoveItem(itm, count)
				
				ObjectReference disp = Display(theForm)
				Drop(product, finalCount)
				Destroy(disp)
				
				ProgressScript.AdvInscription( Math.Floor(product.GetGoldValue() * finalCount) / 10 )
				
				if !TutorialQuest.IsCompleted() && !TutorialQuest.IsObjectiveCompleted(40)
					TutorialQuest.SetStage(40)
				endif
				
				i -= 1
			else
				Debug.Notification("Extraction failed. Invalid Spell Book: " + itm.GetName())
			endif
		elseif ThisActor.HasPerk(DisenchantPerk) 
			int count = self.GetItemCount(theForm)
			if theForm as Scroll
				Scroll itm = theForm as Scroll
				int finalCount = count * itm.GetGoldValue() / 6
				TempStorage.AddItem(ArcaneDust, finalCount)
				self.RemoveItem(itm, count)
				
				ObjectReference disp = Display(theForm)
				Drop(ArcaneDust, finalCount)
				Destroy(disp)

				ProgressScript.AdvInscription( Math.Floor(itm.GetGoldValue() * finalCount) / 20 )
				
				i -= 1
			elseif (theForm as Weapon || theForm as Armor) && ((theForm as Weapon).GetEnchantment() || (theForm as Armor).GetEnchantment())					
				int val = ScrollScribeExtender.GetApproxFullGoldValue(theForm)
				int finalCount = (count * val) / 4
				TempStorage.AddItem(ArcaneDust, finalCount)
				self.RemoveItem(theForm, count)
				
				ObjectReference disp = Display(theForm)
				Drop(ArcaneDust, finalCount)
				Destroy(disp)

				ProgressScript.AdvInscription( finalCount / 10 )
				
				i -= 1
			elseif theForm as SoulGem
				if SoulGemList.HasForm(theForm) || FilledSoulGemList.HasForm(theForm) 
					int finalCount = count * DustPerGemRank.GetValueInt() * (theForm as SoulGem).GetGemSize()
					TempStorage.AddItem(ArcaneDust, finalCount)
					self.RemoveItem(theForm, count)
					
					ObjectReference disp = Display(theForm)
					Drop(ArcaneDust, finalCount)
					Destroy(disp)
					
					i -= 1
				endif
			elseif theForm as Book && theForm.GetGoldValue() > 0
				int finalCount = (count * theForm.GetGoldValue()) / 2
				TempStorage.AddItem(RollOfPaper, finalCount)
				self.RemoveItem(theForm, count)
				
				ObjectReference disp = Display(theForm)
				Drop(RollOfPaper, finalCount, scale = 0.2)
				Destroy(disp)
				
				i -= 1
			endif
		endif
		i += 1
	endwhile
	Utility.Wait(0.1)
	TempStorage.RemoveAllItems(self)
	Self.BlockActivation(abBlocked = False)
	self.Activate(ThisActor)
EndEvent

ObjectReference Function Display(Form theForm)
	ObjectReference Obj
	Obj = StickyMarkerRef.PlaceAtMe(theForm, 1, false, false)
	Obj.SetActorOwner(ThisActor.GetActorBase())
	Obj.BlockActivation()
	Obj.SetScale(0.5)
	Obj.SetAngle(LocalAngleX, LocalAngleY, SpawnAngleZ)
	
	Utility.Wait(0.1)
	Obj.SetMotionType(4)
	Obj.DisableNoWait()
	
	Obj.SetPosition(WorkstationScript.SummonedBenchExtract.X, WorkstationScript.SummonedBenchExtract.Y, WorkstationScript.SummonedBenchExtract.Z + 90.0)
	Obj.EnableNoWait(true)
	Utility.Wait(0.2)
	Obj.SetMotionType(4)
	ExtractSFX.Play(WorkstationScript.SummonedBenchExtract)
	MarkerEffectDestroyItem.Play(Obj)
	return Obj
EndFunction

Function Destroy (ObjectReference ref)
	ref.Disable()
	MarkerEffectDestroyItem.Stop(ref)
	ref.Delete()
EndFunction

Function Drop(Form ItemForm, int count, float scale = 0.33)
	int n = m3Helper.Max(count/10, 1)
	while count > 0
		if DroppedDustListIndex >= MAX_DROPS
			DroppedDustListIndex = 0
		endif
		if DroppedDustList[DroppedDustListIndex] != none
			DroppedDustList[DroppedDustListIndex].Disable()
			DroppedDustList[DroppedDustListIndex].Delete()
		endif
		ObjectReference Obj
		Obj = StickyMarkerRef.PlaceAtMe(ItemForm, 1, FALSE, false)
		Obj.BlockActivation()
		Obj.SetActorOwner(ThisActor.GetActorBase())
		Obj.SetScale(scale)
		Obj.SetPosition(WorkstationScript.SummonedBenchExtract.X + Utility.RandomFloat(-5.0, 5.0), WorkstationScript.SummonedBenchExtract.Y + Utility.RandomFloat(-5.0, 5.0), WorkstationScript.SummonedBenchExtract.Z + 90.0)
		Obj.ApplyHavokImpulse(0.0, 0.0, 1.0, 0.25) ; just a small bump

		DroppedDustList[DroppedDustListIndex] = Obj
		DroppedDustListIndex += 1
		
		count -= n
	endwhile
	Utility.Wait(0.5)
EndFunction

Function ClearDroppedItems()
	int i = 0
	while i < MAX_DROPS
		if DroppedDustList[i]
			DroppedDustList[i].DisableNoWait(true)
			DroppedDustList[i].Delete()
			DroppedDustList[i] = none
		endif
		i += 1
	endwhile
	DroppedDustList = none
	if StickyMarkerRef
		StickyMarkerRef.DisableNoWait(true)
		StickyMarkerRef.Delete()
		StickyMarkerRef = none
	endif
EndFunction