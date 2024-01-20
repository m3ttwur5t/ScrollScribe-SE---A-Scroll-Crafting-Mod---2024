Scriptname _scrFusionBagScript extends ObjectReference  

Actor Property PlayerRef Auto
ObjectReference Property ThisContainer Auto
ObjectReference Property TempStorage  Auto  

Explosion Property SuccessFX  Auto  
Quest Property TutorialQuest  Auto  

Event OnActivate(ObjectReference akActionRef)
	if akActionRef == Game.GetPlayer()
		; wait for player to leave menu
		while(! Game.IsLookingControlsEnabled()) 
			Utility.Wait(0.5)
		EndWhile
		RegisterForSingleUpdate(0.1)
	endif
EndEvent

Event OnUpdate()
	int itemCount = ThisContainer.GetNumItems()
	if itemCount == 0
		return
	elseif itemCount < 2
		Debug.Notification("Scroll fusion requires at least two ingredients.")
		ThisContainer.Activate(PlayerRef)
		return
	endif
	
	bool fusionSuccess = false
	bool ranOnce = false
	bool fusedOnce = false
	while !ranOnce || fusionSuccess
		Scroll firstScroll = none
		fusionSuccess = false
		int i = 0
		while i < ThisContainer.GetNumItems()
			Scroll itm = ThisContainer.GetNthForm(i) as Scroll
			if itm 
				if !firstScroll
					firstScroll = itm
				elseif itm != firstScroll
					if ScrollScribeExtender.CanFuse(firstScroll, itm)
						int countFuse = m3Helper.Min(ThisContainer.GetItemCount(firstScroll), ThisContainer.GetItemCount(itm))
						
						Scroll fusedScroll = ScrollScribeExtender.FuseAndCreate(firstScroll, itm)
						TempStorage.AddItem(fusedScroll, countFuse)
						ThisContainer.RemoveItem(firstScroll, countFuse)
						ThisContainer.RemoveItem(itm, countFuse)
						Utility.Wait(0.1)
						fusionSuccess = true
						fusedOnce = true
						Debug.Notification("Fusion successful: " + fusedScroll.GetName())
					else
						Debug.Notification("Incompatible scrolls: " + firstScroll.GetName() + " and " + itm.GetName())
					endif
				endif
			endif
			i += 1
		endwhile
		ranOnce = true
	endwhile

	if fusedOnce
		PlayerRef.PlaceAtMe(SuccessFX)
		
		if !TutorialQuest.IsCompleted() && !TutorialQuest.IsObjectiveCompleted(55)
			TutorialQuest.SetStage(100)
		endif
	endif
	Utility.Wait(0.1)
	
	TempStorage.RemoveAllItems(ThisContainer)
	ThisContainer.Activate(PlayerRef)
EndEvent
