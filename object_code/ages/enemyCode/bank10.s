; ==============================================================================
; ENEMYID_VERAN_FINAL_FORM
;
; Variables:
;   subid: 0 - turtle, 1 - spider, 2 - bee
;   var03: Attack type (for spider form); 0 - rush, 1 - jump, 2 - grab
;   var30: Current health for turtle form (saved here while in other forms)
;   var31: Spider form max health
;   var32: Bee form max health
;   var33: Nonzero if turtle form has been attacked (will transform)
;   var34: Number of times turtle has jumped (when var33 is nonzero)
;   var35: Used for deciding transformations. Value from 0-7.
;   var36/var37: Target position to move towards
;   var38: Used as a signal by "web" objects?
;   var39: Bee form: quadrant the bee entered the screen from
; ==============================================================================
enemyCode02:
	jr z,@normalStatus
	sub ENEMYSTATUS_NO_HEALTH
	ret c
	jr z,@dead
	dec a
	jr z,@justHit

	; ENEMYSTATUS_KNOCKBACK
	ld c,$20
	call objectUpdateSpeedZ_paramC
	jp _ecom_updateKnockback

@justHit:
	ld h,d
	ld l,Enemy.subid
	ld a,(hl)
	or a
	jr nz,@notTurtleForm

	ld l,Enemy.invincibilityCounter
	ld a,(hl)
	or a
	jr z,@normalStatus

	; Note that turtle veran's been hit and should transform soon
	ld l,Enemy.var33
	ld (hl),$01
	jr @normalStatus

@notTurtleForm:
	ld l,Enemy.knockbackCounter
	ld a,(hl)
	or a
	jr z,@normalStatus

	; Only spider form takes knockback
	ld l,Enemy.state
	ld (hl),$03
	ld l,Enemy.counter1
	ld (hl),105
	ld l,Enemy.enemyCollisionMode
	ld (hl),ENEMYCOLLISION_VERAN_SPIDER_FORM_VULNERABLE

	ld a,(w1Link.state)
	cp LINK_STATE_GRABBED
	call z,_veranFinal_grabbingLink

	ld a,$06
	jp enemySetAnimation

@dead:
	call _veranFinal_dead

@normalStatus:
	ld e,Enemy.subid
	ld a,(de)
	ld e,Enemy.state
	rst_jumpTable
	;.dw _veranFinal_turtleForm
	.dw _veranFinal_spiderForm
	;.dw _veranFinal_beeForm
	.dw _veranFinal_spiderForm
	.dw _veranFinal_spiderForm


_veranFinal_turtleForm:
	ld a,(de)
	rst_jumpTable
	.dw _veranFinal_turtleForm_state0
	.dw _veranFinal_turtleForm_state1
	.dw _veranFinal_turtleForm_state2
	.dw _veranFinal_turtleForm_state3
	.dw _veranFinal_turtleForm_state4
	.dw _veranFinal_turtleForm_state5
	.dw _veranFinal_turtleForm_state6
	.dw _veranFinal_turtleForm_state7
	.dw _veranFinal_turtleForm_state8
	.dw _veranFinal_turtleForm_state9
	.dw _veranFinal_turtleForm_stateA


_veranFinal_turtleForm_state0:
	ld a,$02
	ld (wEnemyIDToLoadExtraGfx),a
	ld a,PALH_87
	call loadPaletteHeader
	;ld a,SNDCTRL_STOPMUSIC
	;call playSound
	ld a,$01
	ld (wDisabledObjects),a
	ld (wMenuDisabled),a

	ld bc,$0208
	call _enemyBoss_spawnShadow
	ret nz
	call _ecom_incState

	call checkIsLinkedGame
	ld l,Enemy.health
	ld a,(hl)
	ld bc,$0c18
	;jr nz,++

	; Unlinked: less health (for all forms)
	ld a,$04
	ld (hl),a
	ld bc,$080f
++
	ld l,Enemy.var30
	ldi (hl),a
	ld (hl),b ; [var31]
	inc l
	ld (hl),c ; [var32]
	jp objectSetVisible83


; Showing text before fight starts
_veranFinal_turtleForm_state1:
	inc e
	ld a,(de) ; [substate]
	rst_jumpTable
	.dw @substate0
	.dw @substate1
	.dw @substate2

@substate0:
	ld a,(wPaletteThread_mode)
	or a
	ret nz
	ld a,SND_LIGHTNING
	call playSound
	ld bc,TX_5614
	call showText
	jp _ecom_incSubstate

@substate1:
	ld h,d
	ld l,e
	inc (hl) ; [substate]
	xor a
	ld (wDisabledObjects),a
	ld (wMenuDisabled),a
	ld a,$03
	call enemySetAnimation
	ld a,MUS_BOSS
	ld (wActiveMusic),a
	jp playSound

@substate2:
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	inc a
	ret nz
	call _ecom_incState
	ld l,Enemy.counter1
	ld (hl),30
	ld l,Enemy.speed
	ld (hl),SPEED_1c0
	inc a
	jp enemySetAnimation


; About to jump
_veranFinal_turtleForm_state2:
	ld e,Enemy.animParameter
	ld a,(de)
	or a
	jp nz,enemyAnimate

	call _ecom_decCounter1
	ret nz
	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.speedZ
	ld (hl),<(-$400)
	inc l
	ld (hl),>(-$400)
	call _ecom_updateAngleTowardTarget
	call objectSetVisible81
	ld a,SND_UNKNOWN4
	call playSound
	ld a,$02
	jp enemySetAnimation


; Jumping (until starts moving down)
_veranFinal_turtleForm_state3:
	ld c,$20
	call objectUpdateSpeedZ_paramC
	ldd a,(hl)
	or (hl)
	jp nz,_ecom_applyVelocityForTopDownEnemyNoHoles

	inc l
	inc (hl) ; [speedZ] = $0100

	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.speed
	ld (hl),SPEED_300
	ld l,Enemy.var36
	ldh a,(<hEnemyTargetY)
	and $f0
	add $08
	ldi (hl),a
	ldh a,(<hEnemyTargetX)
	and $f0
	add $08
	ld (hl),a ; [var37]
	ld a,$01
	jp enemySetAnimation


; Falling and homing in on a position
_veranFinal_turtleForm_state4:
	ld c,$10
	call objectUpdateSpeedZ_paramC
	jr z,@nextState
	call _veranFinal_moveTowardTargetPosition
	ret nc
	ld l,Enemy.yh
	ld (hl),b
	ld l,Enemy.xh
	ld (hl),c
	ret

@nextState:
	ld a,$10
	call setScreenShakeCounter
	call _ecom_incState
	ld l,Enemy.counter1
	ld (hl),$0c
	call objectSetVisible83
	ld a,SND_POOF
	call playSound
	ld b,PARTID_VERAN_ACID_POOL
	jp _ecom_spawnProjectile


; Landed
_veranFinal_turtleForm_state5:
	call _ecom_decCounter1
	ret nz

	ld l,Enemy.speed
	ld (hl),SPEED_1c0
	ld l,Enemy.var33
	bit 0,(hl)
	ld l,Enemy.var34
	jr z,+
	inc (hl)
+
	ld a,(hl)
	ld bc,@transformProbabilities
	call addAToBc
	ld a,(bc)
	ld b,a
	inc a
	ld l,e
	jr z,++

	call getRandomNumber
	and b
	jp z,_veranFinal_transformToBeeOrSpider

	ld e,Enemy.var33
	ld a,(de)
	rrca
	jr c,@jumpAgain
++
	call getRandomNumber
	cp 90
	jr nc,@jumpAgain

	; Open face
	inc (hl) ; [substate] = $06
	ld l,Enemy.counter1
	ld (hl),$08
	ld a,SND_GORON
	call playSound
	ld a,$04
	jp enemySetAnimation

@jumpAgain
	ld (hl),$02 ; [state]
	ld l,Enemy.counter1
	ld (hl),30
	ret

@transformProbabilities:
	.db $ff $03 $03 $01 $00


; Face is opening
_veranFinal_turtleForm_state6:
	call enemyAnimate
	ld h,d
	ld l,Enemy.animParameter
	bit 7,(hl)
	jr nz,@nextState
	bit 0,(hl)
	ret z
	ld l,Enemy.enemyCollisionMode
	ld (hl),ENEMYCOLLISION_VERAN_TURTLE_FORM_VULNERABLE
	ret

@nextState:
	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.counter1
	ld (hl),90
	xor a
	jp enemySetAnimation


_veranFinal_turtleForm_state7:
	call _ecom_decCounter1
	jp nz,enemyAnimate
	ld l,e
	inc (hl) ; [state]
	ld a,$03
	jp enemySetAnimation


_veranFinal_turtleForm_state8:
	call enemyAnimate
	ld h,d
	ld l,Enemy.animParameter
	bit 7,(hl)
	jr nz,@nextState
	bit 0,(hl)
	ret z
	ld l,Enemy.enemyCollisionMode
	ld (hl),ENEMYCOLLISION_VERAN_TURTLE_FORM
	ret

@nextState:
	ld l,Enemy.state
	ld (hl),$02
	ld l,Enemy.counter1
	ld (hl),30
	ld a,$01
	jp enemySetAnimation


; Just transformed back from being a spider or bee
_veranFinal_turtleForm_state9:
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	inc a
	ret nz

	ld h,d
	ld l,Enemy.var33
	ldi (hl),a ; [var33] = 0
	ld (hl),a  ; [var34] = 0

	ld l,Enemy.state
	dec (hl)
	ld l,Enemy.collisionType
	ld (hl),$80|ENEMYID_VERAN_FINAL_FORM
	inc l
	ld (hl),ENEMYCOLLISION_VERAN_TURTLE_FORM_VULNERABLE ; [enemyCollisionType]

	ld l,Enemy.oamFlagsBackup
	ld a,$06
	ldi (hl),a
	ld (hl),a
	ld a,$03
	jp enemySetAnimation


; Dead
_veranFinal_turtleForm_stateA:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw @substate0
	.dw @substate1
	.dw @substate2
	.dw @substate3

@substate0:
	ld e,Enemy.invincibilityCounter
	ld a,(de)
	or a
	ret nz
	call checkLinkVulnerable
	ret nc

	;ld a,$01
	;ld (wMenuDisabled),a
	;ld (wDisabledObjects),a

	call dropLinkHeldItem
	call clearAllParentItems
	call _ecom_incSubstate

	call checkIsLinkedGame
	ld bc,TX_5615
	jr z,+
	ld bc,TX_5616
+
	jp showText

@substate1:
	ld a,(wTextIsActive)
	or a
	ret nz
	call _ecom_incSubstate
	ld l,Enemy.counter2
	ld (hl),40
	ld l,Enemy.yh
	ld b,(hl)
	ld l,Enemy.xh
	ld c,(hl)
	ld a,$ff
	jp createEnergySwirlGoingOut

@substate2:
	call _ecom_decCounter2
	ret nz
	ldbc INTERACID_MISC_PUZZLES, $21
	call objectCreateInteraction
	ret nz
	jp _ecom_incSubstate

@substate3:
	ld a,(wPaletteThread_mode)
	or a
	ret nz
	ld hl,wGroup4Flags+(<ROOM_AGES_4fc)
	set 7,(hl)
	ld a,CUTSCENE_BLACK_TOWER_ESCAPE
	ld (wCutsceneTrigger),a
	call incMakuTreeState
	jp enemyDelete


_veranFinal_spiderForm:
	ld a,(de)
	rst_jumpTable
	.dw _veranFinal_turtleForm_state0
	.dw _veranFinal_turtleForm_state1
	.dw _veranFinal_spiderForm_state2
	.dw _veranFinal_spiderForm_state3
	.dw _veranFinal_spiderForm_state4


_veranFinal_spiderOrBeeForm_state0:
	ret

_veranFinal_spiderForm_state1:
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	inc a
	ret nz

	ld bc,$1010
	ld e,ENEMYCOLLISION_VERAN_SPIDER_FORM
	ld l,$01
	call _veranFinal_initializeForm
	ld a,$05
	call enemySetAnimation

_veranFinal_spiderForm_setCounter2AndInitState2:
	ld e,Enemy.counter2
	ld a,120
	ld (de),a

_veranFinal_spiderForm_initState2:
	ld h,d
	ld l,Enemy.state
	ld (hl),$02
	ld l,Enemy.speed
	ld (hl),SPEED_c0

	call getRandomNumber_noPreserveVars
	and $03
	ld hl,@counter1Vals
	rst_addAToHl
	ld e,Enemy.counter1
	ld a,(hl)
	ld (de),a
	call _veranFinal_spiderForm_decideAngle
	jr _veranFinal_spiderForm_animate

@counter1Vals:
	.db 60,80,100,120


_veranFinal_spiderForm_state2:
	call _ecom_decCounter2
	jr nz,++
	ld (hl),120
	call _veranFinal_spiderForm_decideWhetherToAttack
	ret c
++
	call _ecom_decCounter1
	jr z,_veranFinal_spiderForm_initState2

_veranFinal_spiderForm_updateMovement:
	call _ecom_bounceOffWallsAndHoles
	call objectApplySpeed

_veranFinal_spiderForm_animate:
	jp enemyAnimate


_veranFinal_spiderForm_state3:
	ld e,Enemy.zh
	ld a,(de)
	rlca
	ld c,$20
	jp c,objectUpdateSpeedZ_paramC

	call _ecom_decCounter1
	jr z,@gotoState2

	ld a,(hl)
	rrca
	ret c
	ld l,Enemy.zh
	ld a,(hl)
	xor $02
	ld (hl),a
	ret

@gotoState2:
	ld l,Enemy.zh
	ld (hl),$00
	call objectSetVisible83
	call _veranFinal_spiderForm_resetCollisionData
	jr _veranFinal_spiderForm_initState2


; Doing an attack
_veranFinal_spiderForm_state4:
	ld e,Enemy.var03
	ld a,(de)
	ld e,Enemy.substate
	rst_jumpTable
	.dw _veranFinal_spiderForm_rushAttack
	.dw _veranFinal_spiderForm_jumpAttack
	.dw _veranFinal_spiderForm_webAttack


; Rush toward Link for 1 second
_veranFinal_spiderForm_rushAttack:
	ld a,(de)
	or a
	jr z,@substate0

@substate1:
	call _ecom_decCounter1
	jr z,_veranFinal_spiderForm_setCounter2AndInitState2
	call _veranFinal_spiderForm_updateMovement
	jp enemyAnimate

@substate0:
	call _ecom_incSubstate
	inc l
	ld (hl),60 ; [counter1]
	ld l,Enemy.speed
	ld (hl),SPEED_180

	call _ecom_updateAngleTowardTarget
	and $18
	add $04
	ld (de),a
	jr _veranFinal_spiderForm_animate


; Jumps up and crashes back down onto the ground
_veranFinal_spiderForm_jumpAttack:
	ld a,(de)
	rst_jumpTable
	.dw @substate0
	.dw @substate1
	.dw @substate2
	.dw @substate3
	.dw @substate4

@substate0:
	ld b,PARTID_VERAN_SPIDERWEB
	call _ecom_spawnProjectile
	ret nz
	call _ecom_incSubstate
	ld l,Enemy.var38
	ld (hl),$00
	call _veranFinal_spiderForm_setVulnerableCollisionData
	jp objectSetVisible81

@substate1:
	; Wait for signal from child object?
	ld e,Enemy.var38
	ld a,(de)
	or a
	ret z

	ld h,d
	ld l,Enemy.zh
	ld a,(hl)
	sub $03
	ld (hl),a
	bit 7,a
	jr z,++

	cp $e0
	ret nc

	ldh a,(<hCameraY)
	ld b,a
	ld a,(hl)
	ld l,Enemy.yh
	add (hl)
	sub b
	cp $b0
	ret c
++
	ld l,Enemy.substate
	inc (hl)
	inc l
	ld (hl),90 ; [counter1]
	ld l,Enemy.collisionType
	res 7,(hl)
	ld l,Enemy.zh
	ld (hl),$00
	jp objectSetInvisible

@substate2:
	call _ecom_decCounter1
	ret nz
	ld l,e
	inc (hl) ; [substate]
	ld l,Enemy.collisionType
	set 7,(hl)
	ld l,Enemy.speedZ
	xor a
	ldi (hl),a
	ld (hl),$01

	ld l,Enemy.yh
	ldh a,(<hEnemyTargetY)
	ldi (hl),a
	inc l
	ldh a,(<hEnemyTargetX)
	ld (hl),a
	ld c,$08
	call _ecom_setZAboveScreen
	call _veranFinal_spiderForm_resetCollisionData
	jp objectSetVisible81

@substate3:
	ld c,$20
	call objectUpdateSpeedZ_paramC
	ret nz

	; Landed
	ld l,Enemy.substate
	inc (hl)
	inc l
	ld (hl),120 ; [counter1]
	ld a,SND_STRONG_POUND
	call playSound
	ld a,90
	call setScreenShakeCounter
	jp objectSetVisible83

@substate4:
	call _ecom_decCounter1
	ret nz
	jp _veranFinal_spiderForm_setCounter2AndInitState2


; Shoots out web to try and catch Link
_veranFinal_spiderForm_webAttack:
	ld a,(de)
	rst_jumpTable
	.dw _veranFinal_spiderForm_webAttack_substate0
	.dw _veranFinal_spiderForm_webAttack_substate1
	.dw _veranFinal_spiderForm_webAttack_substate2
	.dw _veranFinal_spiderForm_webAttack_substate3
	.dw _veranFinal_spiderForm_webAttack_substate4
	.dw _veranFinal_spiderForm_webAttack_substate5
	.dw _veranFinal_spiderForm_webAttack_substate6
	.dw _veranFinal_spiderForm_webAttack_substate7


_veranFinal_spiderForm_webAttack_substate0:
	ld h,d
	ld l,e
	inc (hl) ; [substate]
	inc l
	ld (hl),30 ; [counter1]
	ld l,Enemy.var38
	ld (hl),$00

_veranFinal_spiderForm_resetCollisionData:
	ld h,d
	ld l,Enemy.enemyCollisionMode
	ld (hl),ENEMYCOLLISION_VERAN_SPIDER_FORM
	ld l,Enemy.collisionRadiusY
	ld (hl),$10
	ld a,$05
	jp enemySetAnimation


_veranFinal_spiderForm_webAttack_substate1:
	call _ecom_decCounter1
	ret nz
	inc l
	ld (hl),$08 ; [counter2]
	ld l,e
	inc (hl) ; [substate]

_veranFinal_spiderForm_setVulnerableCollisionData:
	ld h,d
	ld l,Enemy.enemyCollisionMode
	ld (hl),ENEMYCOLLISION_VERAN_SPIDER_FORM_VULNERABLE
	ld l,Enemy.collisionRadiusY
	ld (hl),$08
	ld a,$06
	jp enemySetAnimation


_veranFinal_spiderForm_webAttack_substate2:
	call _ecom_decCounter2
	ret nz

	ld b,PARTID_VERAN_SPIDERWEB
	call _ecom_spawnProjectile
	ret nz
	ld l,Part.subid
	inc (hl) ; [subid] = 1
	call _ecom_incSubstate
	inc l
	ld (hl),90 ; [counter1]
	jr _veranFinal_spiderForm_resetCollisionData


; Web coming back?
_veranFinal_spiderForm_webAttack_substate3:
	ld e,Enemy.var38
	ld a,(de)
	or a
	ret z

	call _ecom_decCounter1
	ret nz

	ld a,(w1Link.state)
	cp LINK_STATE_GRABBED
	jp nz,_veranFinal_spiderForm_setCounter2AndInitState2

	; Grabbed
	call _ecom_incSubstate
	inc l
	ld (hl),$10
	ld a,$06
	call enemySetAnimation
	ld b,$f8

_veranFinal_spiderForm_webAttack_updateLinkPosition:
	ld hl,w1Link
	ld c,$00
	jp objectCopyPositionWithOffset


_veranFinal_spiderForm_webAttack_substate4:
	call _ecom_decCounter1
	ret nz

	ld (hl),$04 ; [counter1]
	ld l,e
	inc (hl) ; [substate]
	ld a,$05
	call enemySetAnimation
	ld a,$04
	call setScreenShakeCounter
	ld b,$14
	call _veranFinal_spiderForm_webAttack_updateLinkPosition
	ldbc -6,$08

_veranFinal_spiderForm_webAttack_applyDamageToLink:
	ld l,<w1Link.damageToApply
	ld (hl),b
	ld l,<w1Link.invincibilityCounter
	ld (hl),c
	ld a,SND_STRONG_POUND
	jp playSound


_veranFinal_spiderForm_webAttack_substate5:
	call _ecom_decCounter1
	ret nz
	ld (hl),$08
	ld l,e
	inc (hl)
	ld a,$06
	call enemySetAnimation
	ld b,$f6
	jr _veranFinal_spiderForm_webAttack_updateLinkPosition


_veranFinal_spiderForm_webAttack_substate6:
	call _ecom_decCounter1
	ret nz
	ld (hl),$0f
	ld l,e
	inc (hl)
	ld a,$05
	call enemySetAnimation
	ld a,$14
	call setScreenShakeCounter
	ld b,$14
	call _veranFinal_spiderForm_webAttack_updateLinkPosition
	ldbc -10,$18
	jr _veranFinal_spiderForm_webAttack_applyDamageToLink


_veranFinal_spiderForm_webAttack_substate7:
	call _ecom_decCounter1
	ret nz
	ld l,Enemy.collisionType
	set 7,(hl)
	call _veranFinal_spiderForm_setCounter2AndInitState2


_veranFinal_grabbingLink:
	ld hl,w1Link.substate
	ld (hl),$02
	ld l,<w1Link.collisionType
	set 7,(hl)
	ret


_veranFinal_beeForm:
	ld a,(de)
	rst_jumpTable
	.dw _veranFinal_spiderOrBeeForm_state0
	.dw _veranFinal_beeForm_state1
	.dw _veranFinal_beeForm_state2
	.dw _veranFinal_beeForm_state3
	.dw _veranFinal_beeForm_state4
	.dw _veranFinal_beeForm_state5
	.dw _veranFinal_beeForm_state6
	.dw _veranFinal_beeForm_state7
	.dw _veranFinal_beeForm_state8
	.dw _veranFinal_beeForm_state9
	.dw _veranFinal_beeForm_stateA
	.dw _veranFinal_beeForm_stateB


_veranFinal_beeForm_state1:
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	inc a
	ret nz
	ld a,$07
	call enemySetAnimation
	call _ecom_incState
	ld l,Enemy.speed
	ld (hl),SPEED_200
	ld bc,$100c
	ld e,ENEMYCOLLISION_VERAN_SPIDER_FORM_VULNERABLE
	ld l,Enemy.var32


;;
; @param	bc	collisionRadiusY/X
; @param	e	enemyCollisionMode
; @param	l	Pointer to health value
_veranFinal_initializeForm:
	ld h,d
	ld a,(hl)
	ld l,Enemy.health
	ld (hl),a

	ld l,Enemy.collisionType
	ld (hl),$80|ENEMYID_VERAN_FINAL_FORM
	inc l
	ld (hl),e

	ld l,Enemy.collisionRadiusY
	ld (hl),b
	inc l
	ld (hl),c

	ld l,Enemy.oamFlagsBackup
	ld a,$06
	ldi (hl),a
	ld (hl),a
	ret


_veranFinal_beeForm_state2:
	ld e,Enemy.yh
	ld a,(de)
	ldh (<hFF8F),a
	ld e,Enemy.xh
	ld a,(de)
	ldh (<hFF8E),a
	ldbc LARGE_ROOM_HEIGHT<<3, LARGE_ROOM_WIDTH<<3
	sub c
	add $02
	cp $05
	jr nc,@updateMovement
	ldh a,(<hFF8F)
	sub b
	add $02
	cp $05
	jr nc,@updateMovement

	; In middle of room
	call _ecom_incState
	jp _veranFinal_beeForm_chooseRandomTargetPosition

@updateMovement:
	call _ecom_moveTowardPosition

_veranFinal_beeForm_animate:
	jp enemyAnimate


_veranFinal_beeForm_state3:
	call _veranFinal_moveTowardTargetPosition
	jr nc,_veranFinal_beeForm_animate

	ld l,Enemy.yh
	ld (hl),b
	ld l,Enemy.xh
	ld (hl),c
	call _veranFinal_beeForm_nextTargetPosition
	call _ecom_decCounter2
	jr nz,_veranFinal_beeForm_animate

	; Time to move off screen
	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.counter1
	ld (hl),$01
	ld l,Enemy.xh
	bit 7,(hl)
	ld a,$00
	jr nz,+
	ld a,$f0
+
	ld l,Enemy.var37
	ldd (hl),a
	ld (hl),$e0
	jr _veranFinal_beeForm_animate


; Moving off screen
_veranFinal_beeForm_state4:
	call _ecom_decCounter1
	jr nz,++

	ld (hl),$06 ; [counter1]
	ld l,Enemy.var36
	call _ecom_readPositionVars
	call objectGetRelativeAngleWithTempVars
	call objectNudgeAngleTowards
++
	call objectApplySpeed
	ld e,Enemy.yh
	ld a,(de)
	cp (LARGE_ROOM_HEIGHT+1)<<4
	jr c,_veranFinal_beeForm_animate

	; Off screen
	call _ecom_incState
	ld l,Enemy.counter1
	ld (hl),30
	jp objectSetInvisible


; About to re-emerge on screen
_veranFinal_beeForm_state5:
	call _ecom_decCounter1
	ret nz

	ld (hl),$0f ; [counter1]
	ld l,e
	inc (hl) ; [state]
	ld l,Enemy.yh
	ld (hl),$20

	call getRandomNumber
	and $10
	ldbc $08,$e8
	jr z,++
	ld b,c
	ld c,$08
++
	add $08
	ld l,Enemy.angle
	ld (hl),a
	ld l,Enemy.xh
	ld (hl),b
	ld l,Enemy.var37
	ld (hl),c
	jp objectSetVisible83


; Moving horizontally across screen while attacking
_veranFinal_beeForm_state6:
	call _ecom_decCounter1
	jr nz,++
	ld (hl),$0f ; [counter1]
	ld b,PARTID_VERAN_BEE_PROJECTILE
	call _ecom_spawnProjectile
++
	call objectApplySpeed
	ld e,Enemy.xh
	ld a,(de)
	ld h,d
	ld l,Enemy.var37
	sub (hl)
	inc a
	cp $03
	jp nc,enemyAnimate

	; Reached other side
	call _ecom_incState
	ld l,Enemy.counter1
	ld (hl),60
	ld l,Enemy.collisionType
	res 7,(hl)
	jp objectSetInvisible


; About to re-emerge from some corner of the screen
_veranFinal_beeForm_state7:
	call _ecom_decCounter1
	ret nz

	; Choose which corner to emerge from (not the current one)
	call _veranFinal_getQuadrant
--
	call getRandomNumber
	ld c,a
	and $03
	cp b
	jr z,--

	ld e,Enemy.var39
	ld (de),a
	add a
	ld hl,_veranFinal_beeForm_screenCornerEntrances
	rst_addDoubleIndex
	ld e,Enemy.var36
	ldi a,(hl)
	ld (de),a
	inc e
	ldi a,(hl)
	ld (de),a

	ld e,Enemy.yh
	ldi a,(hl)
	ld (de),a
	ld e,Enemy.xh
	ld a,(hl)
	ld (de),a

	ld a,c
	and $30
	swap a
	add $02
	ld e,Enemy.counter2
	ld (de),a

	call _ecom_incState
	ld l,Enemy.collisionType
	set 7,(hl)
	jp objectSetVisible83


_veranFinal_beeForm_state8:
	call _veranFinal_moveTowardTargetPosition
	jr nc,_veranFinal_beeForm_animate2
	ld l,Enemy.yh
	ld (hl),b
	ld l,Enemy.xh
	ld (hl),c
	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.counter1
	ld (hl),30
	jr _veranFinal_beeForm_animate2


_veranFinal_beeForm_state9:
	call _ecom_decCounter1
	jr nz,_veranFinal_beeForm_animate2
	ld (hl),25 ; [counter1]
	ld l,e
	inc (hl) ; [substate]

_veranFinal_beeForm_animate2:
	jp enemyAnimate


; Shooting out bees
_veranFinal_beeForm_stateA:
	call _ecom_decCounter1
	jr z,_label_10_173

	ld a,(hl) ; [counter1]
	and $07
	jr nz,_veranFinal_beeForm_animate2

	; Spawn child bee
	ld a,(hl)
	and $18
	swap a
	rlca
	dec a
	ld b,a
	call getFreeEnemySlot
	jr nz,_veranFinal_beeForm_animate2

	ld (hl),ENEMYID_VERAN_CHILD_BEE
	inc l
	ld (hl),b ; [child.subid]
	call objectCopyPosition
	ld a,SND_BEAM1
	call playSound
	jr _veranFinal_beeForm_animate2

_label_10_173:
	ld (hl),20 ; [counter1]
	inc l
	dec (hl) ; [counter2]
	ld l,e
	jr z,+
	inc (hl) ; [state] = $0b
	jr _veranFinal_beeForm_animate2
+
	ld (hl),$02 ; [state] = $02
	jr _veranFinal_beeForm_animate2


_veranFinal_beeForm_stateB:
	call _ecom_decCounter1
	jr nz,_veranFinal_beeForm_animate2

	ld l,e
	ld (hl),$08 ; [state]

	call _veranFinal_getQuadrant
@chooseQuadrant:
	call getRandomNumber
	and $03
	cp b
	jr z,@chooseQuadrant
	ld h,d
	ld l,Enemy.var39
	cp (hl)
	jr z,@chooseQuadrant

	ld (hl),a ; [var39]
	add a
	ld hl,_veranFinal_beeForm_screenCornerEntrances
	rst_addDoubleIndex
	ld e,Enemy.var36
	ldi a,(hl)
	ld (de),a
	inc e
	ld a,(hl)
	ld (de),a
	jr _veranFinal_beeForm_animate2


_veranFinal_beeForm_screenCornerEntrances:
	.db $2c $3c $00 $00
	.db $2c $b4 $00 $f0
	.db $84 $3c $b0 $00
	.db $84 $b4 $b0 $f0


;;
; @param	hl	Enemy.state
_veranFinal_transformToBeeOrSpider:
	ld (hl),$01
	ld l,Enemy.collisionType
	ld (hl),$80|ENEMYID_BEAMOS

	ld l,Enemy.health
	ld a,(hl)
	ld l,Enemy.var30
	ld (hl),a

	ld l,Enemy.oamFlagsBackup
	ld a,$07
	ldi (hl),a
	ld (hl),a

	call getRandomNumber_noPreserveVars
	and $03
	ld b,a
	ld e,Enemy.var35
	ld a,(de)
	ld c,a
	inc a
	and $07
	ld (de),a

	ld a,c
	add a
	add a
	add b
	ld hl,@transformSequence
	call checkFlag
	jr z,+
	ld a,$01
+
	inc a
	ld e,Enemy.subid
	ld (de),a
	add $09
	call enemySetAnimation
	ld a,SND_TRANSFORM
	jp playSound

; Each 4 bits is a set of possible values (0=spider, 1=bee).
; [var35] determines which set of 4 bits is randomly chosen from.
; So, for instance, veran always turns into a spider in round 2 due to the 4 '0's?
@transformSequence:
	dbrev %11000000 %11111110 %11101100 %00001111


;;
; @param	b	Distance
; @param[out]	cflag	c if Link is within 'b' pixels of self
_veranFinal_spiderForm_checkLinkWithinDistance:
	ld a,b
	add a
	inc a
	ld c,a
	ld a,(w1Link.yh)
	ld h,d
	ld l,Enemy.yh
	sub (hl)
	add b
	cp c
	ret nc
	ld a,(w1Link.xh)
	ld l,Enemy.xh
	sub (hl)
	add b
	cp c
	ret


;;
; @param[out]	cflag	c if will do an attack (state changed to 4)
_veranFinal_spiderForm_decideWhetherToAttack:
	call objectGetAngleTowardLink
	ld e,a

@considerRushAttack:
	ld b,$60
	call _veranFinal_spiderForm_checkLinkWithinDistance
	jr nc,@considerJumpAttack

	; BUG: is this supposed to 'ld a,e' first? This would check that Link is at a relatively
	; diagonal angle. Instead, this seems to compare their difference in x-positions modulo 8.
	and $07
	sub $03
	cp $03
	ld a,$00
	jr c,@doAttack

@considerJumpAttack:
	ld b,$50
	call _veranFinal_spiderForm_checkLinkWithinDistance
	jr c,@considerGrabAttack

	; Check that Link is diagonal relative to the spider.
	; That shouldn't really matter for this attack, though...
	ld a,e
	and $07
	sub $03
	cp $03
	ccf
	ld a,$01
	jr c,@doAttack

@considerGrabAttack:
	; Check that Link is below the spider
	ld a,e
	sub $0c
	cp $09
	ret nc

	; Grab attack
	ld a,$02

@doAttack:
	ld e,Enemy.var03
	ld (de),a
	ld h,d
	ld l,Enemy.state
	ld (hl),$04
	inc l
	ld (hl),$00 ; [substate]
	scf
	ret


;;
_veranFinal_dead:
	jp _enemyBoss_dead
	ret
	;ld e,Enemy.subid
	;ld a,(de)
	;or a
	;jr nz,@transformed

	; Not transformed; dead for real
	ld h,d
	ld l,Enemy.state
	ld (hl),$0a
	inc l
	ld (hl),$00
	ld l,Enemy.health
	inc (hl)
	ld a,SNDCTRL_STOPMUSIC
	jp playSound

@transformed:
	ld b,a
	ld h,d
	ld l,e
	ld (hl),$00 ; [subid]
	ld l,Enemy.state
	ld (hl),$09

	; Restore turtle health
	ld l,Enemy.var30
	ld a,(hl)
	ld l,Enemy.health
	ld (hl),a

	ld l,Enemy.collisionType
	ld (hl),$80|ENEMYID_BEAMOS

	ld l,Enemy.collisionRadiusY
	ld (hl),$08
	inc l
	ld (hl),$0a ; [collisionRadiusX]

	ld l,Enemy.oamFlagsBackup
	ld a,$07
	ldi (hl),a
	ld (hl),a

	ld a,b ; [subid]
	add $07
	call enemySetAnimation
	ld a,SND_TRANSFORM
	jp playSound


_veranFinal_spiderForm_decideAngle:
	ld b,$00
	ld e,Enemy.yh
	ld a,(de)
	cp (LARGE_ROOM_HEIGHT<<4)/2
	jr c,+
	ld b,$10
+
	ld e,Enemy.xh
	ld a,(de)
	cp (LARGE_ROOM_WIDTH<<4)/2
	jr c,+
	set 3,b
+
	call getRandomNumber
	and $07
	add b
	ld hl,@angles
	rst_addAToHl
	ld e,Enemy.angle
	ld a,(hl)
	ld (de),a
	ret

@angles:
	.db $04 $04 $0c $0c $0c $14 $14 $1c
	.db $04 $0c $0c $14 $14 $14 $1c $1c
	.db $04 $04 $04 $0c $0c $14 $1c $1c
	.db $04 $04 $0c $14 $14 $1c $1c $1c

;;
_veranFinal_beeForm_chooseRandomTargetPosition:
	ld bc,$0801
	call _ecom_randomBitwiseAndBCE
	ld e,Enemy.counter1
	ld a,b
	ld (de),a

	ld a,c
	ld hl,_veranFinal_beeForm_counter2Vals
	rst_addAToHl
	ld e,Enemy.counter2
	ld a,(hl)
	ld (de),a

;;
_veranFinal_beeForm_nextTargetPosition:
	ld e,Enemy.counter1
	ld a,(de)
	ld b,a
	inc a
	and $0f
	ld (de),a
	ld a,b
	ld hl,_veranFinal_beeForm_targetPositions
	rst_addDoubleIndex
	ld e,Enemy.var36
	ldi a,(hl)
	ld (de),a
	inc e
	ld a,(hl)
	ld (de),a ; [var37]
	ret

_veranFinal_beeForm_counter2Vals:
	.db $14 $24

_veranFinal_beeForm_targetPositions:
	.db $38 $80
	.db $20 $90
	.db $20 $b8
	.db $38 $c8
	.db $78 $c8
	.db $90 $b8
	.db $90 $90
	.db $78 $80
	.db $38 $70
	.db $20 $60
	.db $20 $38
	.db $38 $28
	.db $78 $28
	.db $90 $38
	.db $90 $60
	.db $78 $70


;;
_veranFinal_moveTowardTargetPosition:
	ld h,d
	ld l,Enemy.var36
	call _ecom_readPositionVars
	sub c
	add $02
	cp $05
	jr nc,++
	ldh a,(<hFF8F)
	sub b
	add $02
	cp $05
	ret c
++
	call _ecom_moveTowardPosition
	or d
	ret

;;
; @param[out]	b	Value from 0-3 corresponding to screen quadrant
_veranFinal_getQuadrant:
	ld b,$00
	ldh a,(<hEnemyTargetY)
	cp LARGE_ROOM_HEIGHT*16/2
	jr c,+
	ld b,$02
+
	ldh a,(<hEnemyTargetX)
	cp LARGE_ROOM_WIDTH*16/2
	ret c
	inc b
	ret


; ==============================================================================
; ENEMYID_RAMROCK_ARMS
;
; Variables:
;   subid: ?
;   relatedObj1: ENEMYID_RAMROCK
;   var30: ?
;   var32: Shields (subid 4): x-position relative to ramrock
;   var35: Number of times he's been hit in current phase
;   var36: ?
;   var37: ?
;   var38: Used by bomb phase?
; ==============================================================================
enemyCode05:
	ld e,Enemy.state
	ld a,(de)
	rst_jumpTable
	.dw _ramrockArm_state0
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state_stub
	.dw _ramrockArm_state8

_ramrockArm_state0:
	ld e,Enemy.subid
	ld a,(de)
	and $7f
	rst_jumpTable
	.dw @initSubid0
	.dw @initSubid0
	.dw @initSubid2
	.dw @initSubid2
	.dw @initSubid4
	.dw @initSubid4

@initSubid0:
	ld a,(de)
	ld b,a

	ld hl,_ramrockArm_subid0And1XPositions
	rst_addAToHl
	ld a,(hl)
	ld h,d
	ld l,Enemy.xh
	ld (hl),a
	ld l,Enemy.yh
	ld (hl),$10
	ld l,Enemy.zh
	ld (hl),$f9

	ld l,Enemy.angle
	ld (hl),ANGLE_DOWN
	ld l,Enemy.counter1
	ld (hl),$08
	ld a,$00
	add b
	call enemySetAnimation
	ld a,SPEED_180

@commonInit:
	call _ecom_setSpeedAndState8
	jp objectSetVisiblec0

@initSubid2:
	ld a,(de)
	add $02 ; [subid]
	call enemySetAnimation
	call _ramrockArm_setRelativePosition
	ld l,Enemy.zh
	ld (hl),$81
	jr @commonInit

@initSubid4:
	ld a,(de)
	sub $04
	ld b,a
	ld hl,_ramrockArm_subid4And5Angles
	rst_addAToHl
	ld c,(hl)

	ld a,b
	ld hl,_ramrockArm_subid4And5XPositions
	rst_addAToHl
	ld a,(hl)
	ld h,d
	ld l,Enemy.xh
	ldd (hl),a
	dec l
	ld (hl),$4e ; [yh]

	ld l,Enemy.angle
	ld (hl),c
	ld l,Enemy.zh
	ld (hl),$81

	ld l,Enemy.var32
	ld (hl),$04

	ld a,(de) ; [subid]
	add $02
	call enemySetAnimation
	jr @commonInit


_ramrockArm_state_stub:
	ret


_ramrockArm_state8:
	ld e,Enemy.subid
	ld a,(de)
	and $7f
	rst_jumpTable
	.dw _ramrockArm_subid0
	.dw _ramrockArm_subid0
	.dw _ramrockArm_subid2
	.dw _ramrockArm_subid2
	.dw _ramrockArm_subid4
	.dw _ramrockArm_subid4


; "Shields" in first phase
_ramrockArm_subid0:
	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp $04
	jr nz,@runStates

	ld e,Enemy.var31
	ld a,(de)
	or a
	jr nz,@runStates

	inc a
	ld (de),a
	ld e,Enemy.substate
	ld a,$06
	ld (de),a
	ld a,60
	ld e,Enemy.counter1
	ld (de),a

@runStates:
	ld e,Enemy.substate
	ld a,(de)
	rst_jumpTable
	.dw _ramrockArm_subid0_substate0
	.dw _ramrockArm_subid0_substate1
	.dw _ramrockArm_subid0_substate2
	.dw _ramrockArm_subid0_substate3
	.dw _ramrockArm_subid0_substate4
	.dw _ramrockArm_subid0_substate5
	.dw _ramrockArm_subid0_substate6


_ramrockArm_subid0_substate0:
	call enemyAnimate
	call objectApplySpeed
	call _ecom_decCounter1
	ret nz

	ld (hl),$08 ; [counter1]
	ld e,Enemy.subid
	ld a,(de)
	or a
	jr nz,+
	dec a
+
	ld l,Enemy.angle
	add (hl)
	and $1f
	ld (hl),a
	and $0f
	cp $08
	ret nz

	; Angle is now directly left or right
	ld l,Enemy.substate
	inc (hl)
	ld l,Enemy.subid
	ld b,(hl)
	ld l,Enemy.relatedObj1+1
	ld h,(hl)
	ld l,Enemy.subid
	inc (hl)
	ld a,$02
	add b
	jp enemySetAnimation


_ramrockArm_subid0_substate1:
	call enemyAnimate
	call _ramrockArm_setRelativePosition
	ld l,Enemy.relatedObj1+1
	ld h,(hl)
	ld l,Enemy.subid
	ld a,$03
	cp (hl)
	ret nz
	jr _ramrockArm_subid0_moveBackToRamrock


_ramrockArm_subid0_substate2:
	call enemyAnimate
	call _ramrockArm_setRelativePosition
	call _ecom_decCounter2
	ret nz

	ld b,$04
	call objectCheckCenteredWithLink
	ret nc
	call objectGetAngleTowardLink
	cp $10
	ret nz

	call _ecom_incSubstate
	ld l,Enemy.angle
	ld (hl),a
	ld l,Enemy.counter1
	ld (hl),$06
	ld l,Enemy.var30
	ld (hl),$00
	ld l,Enemy.speed
	ld (hl),SPEED_100
	ld l,Enemy.subid
	ld a,$00
	add (hl)
	call enemySetAnimation
	ld a,SND_BIGSWORD
	jp playSound


_ramrockArm_subid0_substate3:
	call objectApplySpeed
	ld e,Enemy.var2a
	ld a,(de)
	cp $80|ITEMCOLLISION_LINK
	jr z,_ramrockArm_subid0_moveBackToRamrock
	cp $80|ITEMCOLLISION_L1_SWORD
	jr z,@sword
	cp $80|ITEMCOLLISION_L2_SWORD
	jr z,@sword
	cp $80|ITEMCOLLISION_L3_SWORD
	jr nz,@moveTowardLink

@sword:
	ld e,Enemy.substate
	ld a,$05
	ld (de),a

	ld a,SPEED_200
	ld e,Enemy.speed
	ld (de),a
	ld e,Enemy.angle
	ld a,(de)
	xor $10
	ld (de),a
	ret

@moveTowardLink:
	call _ecom_getSideviewAdjacentWallsBitset
	jr nz,_ramrockArm_subid0_moveBackToRamrock
	call _ecom_decCounter1
	ret nz
	ld (hl),$06
	call objectGetAngleTowardLink
	jp objectNudgeAngleTowards


_ramrockArm_subid0_moveBackToRamrock:
	ld e,Enemy.substate
	ld a,$04
	ld (de),a
	ld e,Enemy.speed
	ld a,SPEED_180
	ld (de),a

_ramrockArm_subid0_setAngleTowardRamrock:
	call _ramrockArm_getRelativePosition
	call objectGetRelativeAngle
	ld e,Enemy.angle
	ld (de),a
	ret


; Moving back towards Ramrock
_ramrockArm_subid0_substate4:
	call objectApplySpeed
	call _ramrockArm_subid0_setAngleTowardRamrock
	call _ramrockArm_subid0_checkReachedRamrock
	ret nz
	ld a,SND_BOMB_LAND
	call playSound
	ld e,Enemy.substate
	ld a,$02
	ld (de),a
	ld e,Enemy.counter2
	ld a,60
	ld (de),a
	ld e,Enemy.subid
	ld a,(de)
	add $02
	jp enemySetAnimation


; Being knocked back after hit by sword
_ramrockArm_subid0_substate5:
	call enemyAnimate
	ld e,Enemy.var30
	ld a,(de)
	or a
	jr nz,@noDamage
	ld a,Object.start
	call objectGetRelatedObject1Var
	call checkObjectsCollided
	jr nc,@noDamage

	ld e,Enemy.var30
	ld a,$01
	ld (de),a

	ld l,Enemy.invincibilityCounter
	ld a,(hl)
	or a
	jr nz,@noDamage

	ld (hl),60
	ld l,Enemy.var35
	inc (hl)
	ld a,SND_BOSS_DAMAGE
	call playSound

@noDamage:
	xor a
	call _ecom_getSideviewAdjacentWallsBitset
	jp z,objectApplySpeed

	ld e,Enemy.animParameter
	ld a,(de)
	or a
	ret z
	jr _ramrockArm_subid0_moveBackToRamrock


_ramrockArm_subid0_substate6:
	ld e,Enemy.subid
	ld a,(de)
	add $04
	ld b,a
	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp b
	ret nz
	call _ecom_decCounter1
	ret nz

	call objectCreatePuff
	ld a,Object.subid
	call objectGetRelatedObject1Var
	inc (hl)
	jp _ramrockArm_deleteSelf


; Bomb grabber hands
_ramrockArm_subid2:
	ld e,Enemy.substate
	ld a,(de)
	rst_jumpTable
	.dw _ramrockArm_subid2_substate0
	.dw _ramrockArm_subid2_substate1
	.dw _ramrockArm_subid2_substate2

_ramrockArm_subid2_substate0:
	ld c,$10
	call objectUpdateSpeedZ_paramC
	ret nz

	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld (hl),$07

	ld a,SND_SCENT_SEED
	call playSound
	jp _ecom_incSubstate

_ramrockArm_subid2_substate1:
	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp $08
	ret nz

	ld h,d
	ld a,(hl)
	rrca
	jr c,_ramrockArm_deleteSelf

	ld l,Enemy.visible
	res 7,(hl)
	jp _ecom_incSubstate

_ramrockArm_subid2_substate2:
	call _ramrockArm_subid2_copyRamrockPosition
	ld l,Enemy.collisionType
	res 7,(hl)

	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp $0a
	jr z,@relatedSubid0a
	cp $09
	ret nz

@relatedSubid09:
	ld h,d
	ld l,Enemy.collisionType
	set 7,(hl)

	ld c,ITEMID_BOMB
	call findItemWithID
	ret nz

	ld l,Item.yh
	ld b,(hl)
	ld l,Item.xh
	ld c,(hl)
	push hl
	ld e,$06
	call _ramrockArm_checkPositionAtRamrock
	pop hl
	ret nz

	ld l,Item.zh
	ld a,(hl)
	or a
	jr z,++
	cp $fc
	ret c
++
	; Bomb is close enough
	ld l,Item.var2f
	set 4,(hl) ; Delete bomb

	ld a,Object.invincibilityCounter
	call objectGetRelatedObject1Var
	ld a,(hl)
	or a
	ret nz
	ld (hl),60
	ld l,Enemy.var35
	inc (hl)
	ret

; Time to die
@relatedSubid0a:
	ld e,Enemy.subid
	ld a,$01
	ld (de),a
@nextPuff:
	call getFreeInteractionSlot
	ld (hl),INTERACID_PUFF
	push hl
	call _ramrockArm_setRelativePosition
	pop hl
	call objectCopyPosition
	ld e,Enemy.subid
	ld a,(de)
	dec a
	ld (de),a
	jr z,@nextPuff

	ld a,$02
	ld (de),a ; [this.subid]

_ramrockArm_deleteSelf:
	call decNumEnemies
	jp enemyDelete


; Shield hands
_ramrockArm_subid4:
	ld e,Enemy.substate
	ld a,(de)
	rst_jumpTable
	.dw _ramrockArm_subid4_substate0
	.dw _ramrockArm_subid4_substate1
	.dw _ramrockArm_subid4_substate2
	.dw _ramrockArm_subid4_substate3


_ramrockArm_subid4_substate0:
	ld c,$10
	call objectUpdateSpeedZ_paramC
	ret nz
	ld a,$06
	call objectSetCollideRadius
	ld bc,-$80
	call objectSetSpeedZ
	ld l,Enemy.speed
	ld (hl),SPEED_100
	ld l,Enemy.counter2
	ld (hl),62
	jp _ecom_incSubstate


_ramrockArm_subid4_substate1:
	ld e,Enemy.zh
	ld a,(de)
	cp $f9
	ld c,$00
	jp nz,objectUpdateSpeedZ_paramC
	call _ecom_decCounter2
	jp nz,objectApplySpeed

	call _ecom_incSubstate
	ld e,Enemy.subid
	ld a,(de)
	rrca
	ret nc

	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld (hl),$0c

	ld a,PALH_84
	jp loadPaletteHeader


_ramrockArm_subid4_substate2:
	ld a,Object.substate
	call objectGetRelatedObject1Var
	ld a,(hl)
	dec a
	jr z,@updateXPosition

	ld e,Enemy.var2a
	ld a,(de)
	rlca
	jr c,_ramrockArm_subid4_collisionOccurred

	ld a,$02
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp $0d
	jr z,_ramrockArm_subid4_collisionOccurred

	cp $10
	jr nz,@updateXPosition

	call objectCreatePuff
	jr _ramrockArm_deleteSelf

@updateXPosition:
	ld e,Enemy.var32
	ld a,(de)
	ld b,a
	cp $0c
	jr z,_ramrockArm_subid4_updateXPosition
	inc a
	ld (de),a
	ld b,a

; @param	b	X-offset
_ramrockArm_subid4_updateXPosition:
	ld e,Enemy.subid
	ld a,(de)
	rrca
	jr c,++
	ld a,b
	cpl
	inc a
	ld b,a
++
	ld a,Object.xh
	call objectGetRelatedObject1Var
	ld a,(hl)
	add b
	ld e,l
	ld (de),a
	ret

_ramrockArm_subid4_collisionOccurred:
	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld (hl),Object.xh
	ld l,Enemy.var36
	ld (hl),$10
	jp _ecom_incSubstate


_ramrockArm_subid4_substate3:
	ld e,Enemy.var2a
	ld a,(de)
	rlca
	jr nc,++

	ld a,Object.var36
	call objectGetRelatedObject1Var
	ld (hl),$10
++
	ld e,Enemy.var32
	ld a,(de)
	sub $02
	cp $04
	jr nc,+
	ld b,$04
	jr ++
+
	ld (de),a
	ld b,a
	jr _ramrockArm_subid4_updateXPosition
++
	ld a,Object.subid
	call objectGetRelatedObject1Var
	ld a,(hl)
	cp $0d
	jr z,_ramrockArm_subid4_updateXPosition

	ld e,Enemy.substate
	ld a,$02
	ld (de),a
	jr _ramrockArm_subid4_updateXPosition


;;
_ramrockArm_setRelativePosition:
	call _ramrockArm_getRelativePosition
	ld h,d
	ld l,Enemy.yh
	ld (hl),b
	ld l,Enemy.xh
	ld (hl),c
	ret

;;
; @param[out]	zflag
_ramrockArm_subid0_checkReachedRamrock:
	call _ramrockArm_getRelativePosition
	ld e,$02

;;
; @param	bc	Position
; @param	e
_ramrockArm_checkPositionAtRamrock:
	ld h,d
	ld l,Enemy.yh
	ld a,e
	add b
	cp (hl)
	jr c,_label_10_212
	sub e
_label_10_211:
	sub e
	cp (hl)
	jr nc,_label_10_212
	ld l,Enemy.xh
	ld a,e
	add c
	cp (hl)
	jr c,_label_10_212
	sub e
	sub e
	cp (hl)
	jr nc,_label_10_212
	xor a
	ret
_label_10_212:
	or d
	ret

;;
; @param[out]	bc	Relative position
_ramrockArm_getRelativePosition:
	ld e,Enemy.subid
	ld a,(de)
	ld c,$0e
	rrca
	jr nc,+
	ld c,-$0e
+
	ld a,Object.yh
	call objectGetRelatedObject1Var
	ldi a,(hl)
	add $08
	ld b,a
	inc l
	ld a,(hl) ; [object.xh]
	add c
	ld c,a
	ret

;;
_ramrockArm_subid2_copyRamrockPosition:
	ld a,Object.yh
	call objectGetRelatedObject1Var
	ldi a,(hl)
	add $08
	ld b,a
	inc l
	ld a,(hl)
	ld h,d
	ld l,Enemy.xh
	ldd (hl),a
	dec l
	ld (hl),b
	ret

_ramrockArm_subid0And1XPositions:
	.db $30 $c0

_ramrockArm_subid4And5XPositions:
	.db $37 $b9

_ramrockArm_subid4And5Angles:
	.db $08 $18


; ==============================================================================
; ENEMYID_VERAN_FAIRY
;
; Variables:
;   var03: Attack index
;   var30: Movement pattern index (0-3)
;   var31/var32: Pointer to movement pattern
;   var33/var34: Target position to move to
;   var35: Number from 0-2 based on health (lower means more health)
;   var36: ?
;   var38: Timer to stay still after doing a movement pattern
; ==============================================================================
enemyCode06:
	jr z,@normalStatus
	sub ENEMYSTATUS_NO_HEALTH
	ret c
	jr nz,@justHit

	; No health
	ld e,Enemy.invincibilityCounter
	ld a,(de)
	ret nz
	call checkLinkCollisionsEnabled
	ret nc

	ld a,DISABLE_LINK
	ld (wDisabledObjects),a
	ld (wMenuDisabled),a
	ld h,d
	ld l,Enemy.health
	inc (hl)
	ld l,Enemy.state
	ld (hl),$05
	inc l
	ld (hl),$00 ; [substate]
	ld l,Enemy.counter1
	ld (hl),60
	jr @normalStatus

@justHit:
	call _veranFairy_updateVar35BasedOnHealth
	ld hl,_veranFairy_speedTable
	rst_addAToHl
	ld e,Enemy.speed
	ld a,(hl)
	ld (de),a

@normalStatus:
	ld e,Enemy.state
	ld a,(de)
	rst_jumpTable
	.dw _veranFairy_state0
	.dw _veranFairy_state1
	.dw _veranFairy_state2
	.dw _veranFairy_state3
	.dw _veranFairy_state4
	.dw _veranFairy_state5

_veranFairy_state0:
	ld a,ENEMYID_VERAN_FAIRY
	ld (wEnemyIDToLoadExtraGfx),a
	call _ecom_incState
	ld l,Enemy.counter1
	ld (hl),60
	ld l,Enemy.speed
	ld (hl),SPEED_140
	ld l,Enemy.var30
	dec (hl)
	ld a,$02
	call enemySetAnimation
	jp objectSetVisible82

; Cutscene just prior to fairy form
_veranFairy_state1:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw @substate0
	.dw @substate1
	.dw @substate2
	.dw @substate3
	.dw @substate4
	.dw @substate5
	.dw @substate6
	.dw @substate7
	.dw @substate8
	.dw @substate9
	.dw @substateA
	.dw @substateB
	.dw @substateC

@substate0:
	call _ecom_decCounter1
	jp nz,_ecom_flickerVisibility
	ld (hl),$08
	ld l,e
	inc (hl) ; [substate]
	jp objectSetVisible83

@substate1:
	call _ecom_decCounter1
	ret nz
	ld l,e
	inc (hl) ; [substate]
	ld bc,TX_560f
	jp showText

@substate2:
	call _ecom_incSubstate
	ld l,Enemy.counter1
	ld (hl),30
	ld a,$04
	jp enemySetAnimation

@substate3:
	ld c,$33

@strikeLightningAfterCountdown:
	call _ecom_decCounter1
	ret nz
	ld (hl),10 ; [counter1]
	ld l,e
	inc (hl) ; [substate]

@strikeLightning:
	call getFreePartSlot
	ret nz
	ld (hl),PARTID_LIGHTNING
	ld l,Part.yh
	jp setShortPosition_paramC

@substate4:
	ld c,$7b
	jr @strikeLightningAfterCountdown

@substate5:
	ld c,$55
	jr @strikeLightningAfterCountdown

@substate6:
	ld c,$3b
	jr @strikeLightningAfterCountdown

@substate7:
	ld c,$73
	jr @strikeLightningAfterCountdown

@substate8:
	call _ecom_decCounter1
	ret nz
	ld l,e
	inc (hl) ; [substate]
	ld c,$59
	call @strikeLightning
	jp fadeoutToWhite

; Remove pillar tiles
@substate9:
	ld b,$0c
	ld hl,@pillarPositions
@loop
	push bc
	ldi a,(hl)
	ld c,a
	ld a,$a5
	push hl
	call setTile
	pop hl
	pop bc
	dec b
	jr nz,@loop
	jp _ecom_incSubstate

@pillarPositions:
	.db $23 $33 $63 $73 $45 $55 $49 $59
	.db $2b $3b $6b $7b

; Spawn mimics
@substateA:
	ld b,$04
	ld hl,@mimicPositions

@nextMimic:
	ldi a,(hl)
	ld c,a
	push hl
	call getFreeEnemySlot
	jr nz,++
	ld (hl),ENEMYID_LINK_MIMIC
	ld l,Enemy.yh
	call setShortPosition_paramC
++
	pop hl
	dec b
	jr nz,@nextMimic

	call _ecom_incSubstate
	ld l,Enemy.counter1
	ld (hl),30

	ld l,Enemy.oamFlagsBackup
	xor a
	ldi (hl),a
	ld (hl),a

	ld l,Enemy.zh
	dec (hl)
	call objectSetVisible83
	ld a,$05
	call enemySetAnimation
	ld a,$04
	jp fadeinFromWhiteWithDelay

@mimicPositions:
	.db $33 $73 $3b $7b

@substateB:
	ld a,(wPaletteThread_mode)
	or a
	ret nz
	call _ecom_decCounter1
	ret nz
	ld l,e
	inc (hl)
	ld bc,TX_5610
	jp showText

@substateC:
	ld h,d
	ld l,Enemy.state
	inc (hl)
	ld l,Enemy.counter2
	ld (hl),120
	jp _enemyBoss_beginBoss


; Choosing a movement pattern and attack
_veranFairy_state2:
	call getRandomNumber_noPreserveVars
	and $07
	ld b,a
	ld e,Enemy.var35
	ld a,(de)
	swap a
	rrca
	add b
	ld hl,_veranFairy_attackTable
	rst_addAToHl
	ld e,Enemy.var03
	ld a,(hl)
	ld (de),a

	call _ecom_incState
	ld l,Enemy.var38
	ld (hl),60
	ld l,Enemy.var36
	ld (hl),$00
--
	call getRandomNumber
	and $03
	ld l,Enemy.var30
	cp (hl)
	jr z,--
	ld (hl),a

	ld hl,_veranFairy_movementPatternTable
	rst_addDoubleIndex
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	ld e,Enemy.var33
	ldi a,(hl)
	ld (de),a
	inc e
	ldi a,(hl) ; [var34]
	ld (de),a

_veranFairy_saveMovementPatternPointer:
	ld e,Enemy.var31
	ld a,l
	ld (de),a
	inc e
	ld a,h
	ld (de),a
	ret


; Moving and attacking
_veranFairy_state3:
	call _veranFairy_66ed

	ld h,d
	ld l,Enemy.var33
	call _ecom_readPositionVars
	sub c
	add $02
	cp $05
	jr nc,@updateMovement
	ldh a,(<hFF8F)
	sub b
	add $02
	cp $05
	jr nc,@updateMovement

	; Reached target position
	ld l,Enemy.yh
	ld (hl),b
	ld l,Enemy.xh
	ld (hl),c
	call _veranFairy_checkLoopAroundScreen

	; Get next target position
	ld h,d
	ld l,Enemy.var31
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	ldi a,(hl)
	or a
	jr nz,++
	ld a,$05
	call enemySetAnimation
	jp _ecom_incState
++
	ld e,Enemy.var33
	ld (de),a
	ld b,a
	inc e
	ldi a,(hl)
	ld (de),a ; [var34]
	ld c,a
	call _veranFairy_saveMovementPatternPointer
@updateMovement:
	call _ecom_moveTowardPosition
_veranFairy_animate:
	jp enemyAnimate


_veranFairy_state4:
	ld h,d
	ld l,Enemy.var38
	dec (hl)
	jr nz,_veranFairy_animate
	ld l,e
	ld (hl),$02 ; [state]
	jr _veranFairy_animate


; Dead
_veranFairy_state5:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw @substate0
	.dw @substate1
	.dw @substate2

@substate0:
	call _ecom_decCounter1
	jp nz,_ecom_flickerVisibility
	ld l,e
	inc (hl)
	jp objectSetVisible82

@substate1:
	call _ecom_incSubstate
	ld l,Enemy.counter2
	ld (hl),65
	ld bc,TX_5612
	jp showText

@substate2:
	call _ecom_decCounter2
	jr z,@triggerCutscene

	ld a,(hl) ; [counter2]
	and $0f
	ret nz
	ld a,(hl) ; [counter2]
	and $f0
	swap a
	dec a
	push af
	dec a
	call z,fadeoutToWhite
	pop af
	ld hl,@explosionPositions
	rst_addDoubleIndex
	ldi a,(hl)
	ld c,(hl)
	ld b,a
	call getFreeInteractionSlot
	ret nz
	ld (hl),INTERACID_EXPLOSION
	ld l,Interaction.var03
	inc (hl) ; [explosion.var03] = $01
	jp objectCopyPositionWithOffset

@triggerCutscene:
	ld a,(wPaletteThread_mode)
	or a
	ret nz
	call clearAllParentItems
	call dropLinkHeldItem
	ld a,CUTSCENE_BLACK_TOWER_ESCAPE_ATTEMPT
	ld (wCutsceneTrigger),a
	jp enemyDelete

@explosionPositions:
	.db $f0 $f0
	.db $10 $08
	.db $f8 $04
	.db $08 $f8


; BUG(?): $00 acts as a terminator, but it's also used as a position value, meaning one movement
; pattern stops early? (Doesn't apply if $00 is in the first row.)
_veranFairy_movementPatternTable:
	.dw @pattern0
	.dw @pattern1
	.dw @pattern2
	.dw @pattern3

@pattern0:
	.db $00 $78
	.db $00 $f7 ; Terminates early here?
	.db $c0 $e0
	.db $58 $78
	.db $00
@pattern1:
	.db $00 $f7
	.db $58 $78
	.db $58 $f7
	.db $c0 $f7
	.db $58 $78
	.db $00
@pattern2:
	.db $58 $f7
	.db $30 $f7
	.db $c0 $38
	.db $c0 $b8
	.db $58 $78
	.db $00
@pattern3:
	.db $00 $f7
	.db $c0 $f7
	.db $10 $f7
	.db $90 $f7
	.db $58 $78
	.db $00


_veranFairy_attackTable:
	.db $00 $00 $00 $00 $00 $00 $01 $01 ; High health
	.db $00 $00 $00 $00 $00 $01 $01 $02 ; Mid health
	.db $00 $00 $01 $01 $01 $02 $02 $02 ; Low health


_veranFairy_speedTable:
	.db SPEED_140, SPEED_1c0, SPEED_200

;;
_veranFairy_checkLoopAroundScreen:
	call objectGetShortPosition
	ld e,a
	ld hl,@data1
	call lookupKey
	ret nc

	ld hl,@data2
	rst_addAToHl
	ld e,Enemy.yh
	ldi a,(hl)
	ld (de),a
	ldh (<hFF8F),a
	ld e,Enemy.xh
	ld a,(hl)
	ld (de),a
	ldh (<hFF8E),a
	ret

@data1:
	.db $07 $00
	.db $0f $02
	.db $1f $04
	.db $3f $06
	.db $5f $08
	.db $9f $0a
	.db $c3 $0c
	.db $cb $0a
	.db $ce $0e
	.db $cf $00
	.db $00

@data2:
	.db $c0 $00
	.db $00 $00
	.db $90 $00
	.db $00 $38
	.db $30 $00
	.db $58 $00
	.db $00 $b8
	.db $c0 $78

;;
; @param[out]	a	Value written to var35
_veranFairy_updateVar35BasedOnHealth:
	ld b,$00
	ld e,Enemy.health
	ld a,(de)
	cp 20
	jr nc,++
	inc b
	cp 10
	jr nc,++
	inc b
++
	ld e,Enemy.var35
	ld a,b
	ld (de),a
	ret

;;
_veranFairy_66ed:
	call _ecom_decCounter2
	ret nz
	ld e,Enemy.var03
	ld a,(de)
	rst_jumpTable
	.dw attack0
	.dw attack1
	.dw attack2

; Shooting occasional projectiles
attack0:
	ld e,Enemy.var36
	ld a,(de)
	or a
	jr nz,@label_10_227

	call getRandomNumber_noPreserveVars
	and $0f
	ld b,a
	ld h,d
	ld l,Enemy.var35
	ld a,(hl)
	add a
	add $08
	cp b
	ld l,Enemy.counter2
	ld (hl),60
	ret nc

	xor a
	ldd (hl),a
	inc a
	ld (hl),a
	ld l,Enemy.var36
	ld (hl),a
	ld l,Enemy.var37
	ld (hl),$04

@label_10_227:
	call _ecom_decCounter1
	jr z,@label_10_228
	ld a,(hl)
	cp $0e
	ret nz
	ld a,$05
	jp enemySetAnimation

@label_10_228:
	call _veranFairy_checkWithinBoundary
	ret nc
	ld l,Enemy.var37
	dec (hl)
	jr z,@label_10_229

	ld l,Enemy.counter1
	ld (hl),30

	ld b,PARTID_VERAN_FAIRY_PROJECTILE
	call _ecom_spawnProjectile
	ld a,$06
	jp enemySetAnimation

@label_10_229:
	ld l,Enemy.counter2
	ld (hl),90
	ld l,Enemy.var36
	ld (hl),$00
	ret

; Circular projectile attack
attack1:
	ld e,Enemy.var36
	ld a,(de)
	or a
	jr nz,@label_10_230

	call _veranFairy_checkWithinBoundary
	ret nc

	call getRandomNumber_noPreserveVars
	and $0f
	ld b,a
	ld h,d
	ld l,Enemy.var35
	ld a,(hl)
	add a
	add $06
	cp b
	ld l,Enemy.counter2
	ld (hl),90
	ret nc

	ld (hl),$00 ; [counter2]
	dec l
	ld (hl),180 ; [counter1]
	ld l,Enemy.var36
	ld (hl),$01

	ld b,PARTID_VERAN_PROJECTILE
	call _ecom_spawnProjectile
	ld a,$06
	call enemySetAnimation

@label_10_230:
	pop hl
	call _ecom_decCounter1
	jp nz,enemyAnimate

	inc l
	ld (hl),120 ; [counter2]
	ld l,Enemy.var36
	ld (hl),$00
	ld a,$05
	jp enemySetAnimation

; Baby ball attack
attack2:
	ld h,d
	ld l,Enemy.var36
	bit 0,(hl)
	jr nz,@label_10_231

	call _veranFairy_checkWithinBoundary
	ret nc

	ld (hl),$01
	ld l,Enemy.counter1
	ld (hl),30
	ld b,PARTID_BABY_BALL
	call _ecom_spawnProjectile
	ld a,$06
	call enemySetAnimation

@label_10_231:
	pop hl
	call _ecom_decCounter1
	jp nz,enemyAnimate

	inc l
	ld (hl),$f0
	ld l,Enemy.var36
	ld (hl),$00
	ld a,$05
	jp enemySetAnimation

;;
; @param[out]	cflag	nc if veran is outside the room boundary
_veranFairy_checkWithinBoundary:
	ld e,Enemy.yh
	ld a,(de)
	sub $10
	cp $90
	ret nc
	ld e,Enemy.xh
	ld a,(de)
	sub $10
	cp $d0
	ret


; ==============================================================================
; ENEMYID_RAMROCK
;
; Variables:
;   var30: Set to $01 by hands when they collide with ramrock
;   var35: Incremented by hands when hit by bomb?
;   var36: Written to by shield hands?
; ==============================================================================
enemyCode07:
	ld e,Enemy.state
	ld a,(de)
	rst_jumpTable
	.dw _ramrock_state0
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state_stub
	.dw _ramrock_state8
	.dw _ramrock_swordPhase
	.dw _ramrock_bombPhase
	.dw _ramrock_seedPhase
	.dw _ramrock_glovePhase


_ramrock_state0:
	ld a,ENEMYID_RAMROCK
	ld b,PALH_83
	call _enemyBoss_initializeRoom
	ld a,SPEED_100
	call _ecom_setSpeedAndState8
	ld a,$04
	call enemySetAnimation
	ld b,$00
	ld c,$0c
	call _enemyBoss_spawnShadow
	jp objectSetVisible81


_ramrock_state_stub:
	ret


; Cutscene before fight
_ramrock_state8:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw _ramrock_state8_substate0
	.dw _ramrock_state8_substate1
	.dw _ramrock_state8_substate2
	.dw _ramrock_state8_substate3
	.dw _ramrock_state8_substate4
	.dw _ramrock_state8_substate5

_ramrock_state8_substate0:
	ld a,DISABLE_LINK
	ld (wDisabledObjects),a
	ld (wMenuDisabled),a
	ld a,($cc93)
	or a
	ret nz

	ld e,Enemy.stunCounter
	ld a,60
	ld (de),a
	jp _ecom_incSubstate

_ramrock_state8_substate1:
	ld e,Enemy.stunCounter
	ld a,(de)
	or a
	ret nz

	ld bc,-$80
	call objectSetSpeedZ
	ld c,$00
	call objectUpdateSpeedZ_paramC
	ld e,Enemy.zh
	ld a,(de)
	cp $f9
	ret nz

	ld c,$01
@spawnArm:
	ld b,ENEMYID_RAMROCK_ARMS
	call _ecom_spawnEnemyWithSubid01
	ld l,Enemy.subid
	ld (hl),c
	ld l,Enemy.relatedObj1
	ld (hl),Enemy.start
	inc l
	ld (hl),d
	dec c
	jr z,@spawnArm

	jp _ecom_incSubstate

_ramrock_state8_substate2:
	ld e,Enemy.subid
	ld a,(de)
	cp $02
	ret nz
	ld e,Enemy.counter1
	ld a,$02
	ld (de),a
	call _ecom_incSubstate
	ld a,PALH_84
	jp loadPaletteHeader

_ramrock_state8_substate3:
	call _ecom_decCounter1
	ret nz
	call _ecom_incSubstate
	ld a,SND_SWORD_OBTAINED
	call playSound
	ld l,Enemy.subid
	inc (hl)
	ld a,PALH_83
	jp loadPaletteHeader

_ramrock_state8_substate4:
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	or a
	ret z
	call _ecom_incSubstate
	ld l,Enemy.angle
	ld (hl),$00
	ld a,$00
	call enemySetAnimation

_ramrock_state8_substate5:
	call enemyAnimate
	call objectApplySpeed
	ld e,Enemy.yh
	ld a,(de)
	cp $41
	ret nc

	; Fight begins
	xor a
	ld (wDisabledObjects),a
	ld (wMenuDisabled),a
	call _ecom_incState
	ld l,$89
	ld (hl),$08
	ld l,$82
	ld (hl),$03
	ld a,MUS_BOSS
	jp playSound


; "Fist" phase
_ramrock_swordPhase:
	call enemyAnimate
	ld e,Enemy.var35
	ld a,(de)
	cp $03
	jr nc,+
	jp _ramrock_updateHorizontalMovement
+
	xor a
	ld (de),a
	ld bc,$0000
	call objectSetSpeedZ
	call _ecom_incState
	inc l
	ld (hl),$00
	ld l,Enemy.subid
	inc (hl)
	ld l,Enemy.counter2
	ld (hl),30
	ld a,$04
	jp enemySetAnimation


; "Bomb" phase
_ramrock_bombPhase:
	call @func_68fe

	; Stop movement of any bombs that touch ramrock
	ld c,ITEMID_BOMB
	call findItemWithID
	ret nz
	call checkObjectsCollided
	jr nc,++
	ld l,Item.angle
	ld (hl),$ff
++
	ld c,ITEMID_BOMB
	call findItemWithID_startingAfterH
	ret nz
	call checkObjectsCollided
	ret nc
	ld l,Item.angle
	ld (hl),$ff
	ret

@func_68fe:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw _ramrock_bombPhase_substate0
	.dw _ramrock_bombPhase_substate1
	.dw _ramrock_bombPhase_substate2
	.dw _ramrock_bombPhase_substate3
	.dw _ramrock_bombPhase_substate4

_ramrock_bombPhase_substate0:
	ld c,$10
	call objectUpdateSpeedZ_paramC
	ld e,Enemy.subid
	ld a,(de)
	cp $06
	ret nz
	call _ecom_decCounter2
	ret nz

	; Spawn arms
	ld b,ENEMYID_RAMROCK_ARMS
	call _ecom_spawnEnemyWithSubid01
	ld l,Enemy.subid
	ld (hl),$02
	ld l,Enemy.relatedObj1
	ld (hl),Enemy.start
	inc l
	ld (hl),d

	ld b,ENEMYID_RAMROCK_ARMS
	call _ecom_spawnEnemyWithSubid01
	ld l,Enemy.subid
	ld (hl),$03
	ld l,Enemy.relatedObj1
	ld (hl),Enemy.start
	inc l
	ld (hl),d

	jp _ecom_incSubstate

_ramrock_bombPhase_substate1:
	ld e,Enemy.subid
	ld a,(de)
	cp $07
	ret nz

	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	or a
	ret z
	ld bc,-$80
	call objectSetSpeedZ
	ld l,Enemy.subid
	ld (hl),$08
	ld a,$01
	call enemySetAnimation
	jp _ecom_incSubstate

_ramrock_bombPhase_substate2:
	ld c,$00
	call objectUpdateSpeedZ_paramC
	ld e,Enemy.zh
	ld a,(de)
	cp $f9
	ret nz

	ld a,SND_SWORD_OBTAINED
	call playSound

_ramrock_bombPhase_gotoSubstate3:
	ld h,d
	ld l,Enemy.counter1
	ld a,$04
	ldi (hl),a
	ld (hl),50 ; [counter2]
	ld l,Enemy.substate
	ld (hl),$03
	ret

_ramrock_bombPhase_substate3:
	ld e,Enemy.var38
	ld a,(de)
	sub $01
	ld (de),a
	jr nc,++
	ld a,30
	ld (de),a
	ld a,SND_BEAM1
	call playSound
++
	ld e,Enemy.var35
	ld a,(de)
	cp $03
	jr nc,_label_10_237

	call enemyAnimate
	call _ecom_applyVelocityForSideviewEnemy
	call _ecom_decCounter2
	jr z,_label_10_236

	call _ecom_decCounter1
	ret nz

	ld (hl),$04
	call objectGetAngleTowardLink
	jp objectNudgeAngleTowards

_label_10_236:
	call _ecom_incSubstate
	ld a,$02
	jp enemySetAnimation

_label_10_237:
	call _ecom_incState
	inc l
	xor a
	ld (hl),a
	ld l,Enemy.var35
	ld (hl),a
	ld l,Enemy.subid
	ld (hl),$0a
	ld a,$04
	jp enemySetAnimation

_ramrock_bombPhase_substate4:
	call enemyAnimate
	ld h,d
	ld l,Enemy.subid
	ld (hl),$08
	ld e,Enemy.animParameter
	ld a,(de)
	cp $01
	jr nz,++
	ld l,Enemy.subid
	ld (hl),$09
	ld a,SND_STRONG_POUND
	jp playSound
++
	rla
	ret nc
	ld a,$01
	call enemySetAnimation
	jp _ramrock_bombPhase_gotoSubstate3


; "Seed" phase
_ramrock_seedPhase:
	ld h,d
	ld l,Enemy.substate
	ld a,(hl)
	or a
	jr z,@runSubstate
	dec a
	jr z,@runSubstate

	ld e,Enemy.var2a
	ld a,(de)
	cp $80|ITEMCOLLISION_MYSTERY_SEED
	jr c,@noSeedCollision
	cp $80|ITEMCOLLISION_GALE_SEED+1
	jr c,@seedCollision

@noSeedCollision:
	rlca
	jr nc,@noCollision

@otherCollision:
	ld l,Enemy.subid
	ld (hl),$0d
	ld l,Enemy.var36
	ld (hl),$10
	jr @runSubstate

@seedCollision:
	ld l,Enemy.invincibilityCounter
	ld a,(hl)
	or a
	jr nz,@otherCollision

	ld (hl),60 ; [invincibilityCounter]
	ld l,Enemy.var35
	ld a,(hl)
	cp $03
	jr z,@seedPhaseEnd

	inc (hl)
	ld a,SND_BOSS_DAMAGE
	call playSound
	jr @runSubstate

@noCollision:
	ld l,Enemy.var36
	ld a,(hl)
	or a
	jr z,@runSubstate
	dec (hl)
	jr nz,@runSubstate

	ld l,Enemy.subid
	ld (hl),$0c

@runSubstate:
	ld e,Enemy.substate
	ld a,(de)
	rst_jumpTable
	.dw _ramrock_seedPhase_substate0
	.dw _ramrock_seedPhase_substate1
	.dw _ramrock_seedPhase_substate2
	.dw _ramrock_seedPhase_substate3
	.dw _ramrock_seedPhase_substate4
	.dw _ramrock_seedPhase_substate5
	.dw _ramrock_seedPhase_substate6

@seedPhaseEnd:
	ld l,Enemy.subid
	ld (hl),$10
	call _ecom_incState
	inc l
	xor a
	ld (hl),a
	ld l,Enemy.var35
	ld (hl),a
	ret

_ramrock_seedPhase_substate0:
	ld h,d
	ld bc,$4878
	ld l,Enemy.yh
	ldi a,(hl)
	cp b
	jr nz,@updateMovement

	inc l
	ld a,(hl)
	cp c
	jr nz,@updateMovement

	ld l,Enemy.subid
	inc (hl)
	ld l,Enemy.counter2
	ld (hl),$02

	ld c,$04
@spawnArm:
	ld b,ENEMYID_RAMROCK_ARMS
	call _ecom_spawnEnemyWithSubid01
	ld l,Enemy.subid
	ld (hl),c
	ld l,Enemy.relatedObj1
	ld (hl),Enemy.start
	inc l
	ld (hl),d
	inc c
	ld a,c
	cp $05
	jr z,@spawnArm

	jp _ecom_incSubstate

@updateMovement:
	call objectGetRelativeAngle
	ld e,Enemy.angle
	ld (de),a
	jp objectApplySpeed

_ramrock_seedPhase_substate1:
	ld e,Enemy.subid
	ld a,(de)
	cp $0c
	ret nz

	ld e,Enemy.counter2
	ld a,(de)
	or a
	jr nz,_label_10_248

	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	or a
	ret z

_ramrock_seedPhase_6a94:
	ld e,Enemy.subid
	ld a,$0c
	ld (de),a

_ramrock_seedPhase_resumeNormalMovement:
	ld h,d
	ld l,Enemy.substate
	ld (hl),$02
	ld l,Enemy.counter2
	ld (hl),120
	ld a,$00
	jp enemySetAnimation

_label_10_248:
	call _ecom_decCounter2
	ret nz
	ld l,Enemy.angle
	ld (hl),$08
	ld a,PALH_83
	call loadPaletteHeader
	ld a,SND_SWORD_OBTAINED
	jp playSound

; Moving normally
_ramrock_seedPhase_substate2:
	call enemyAnimate
	call _ramrock_updateHorizontalMovement

	call getRandomNumber
	rrca
	ret nc
	call _ecom_decCounter2
	ret nz

	ld e,Enemy.subid
	ld a,(de)
	cp $0c
	ret nz

	call getRandomNumber
	and $03
	ld l,e
	jr z,@gotoNextSubstate

	ld (hl),$0f ; [counter2]
	ld l,Enemy.substate
	ld (hl),$06
	ld l,Enemy.counter1
	ld (hl),60

	ld b,PARTID_RAMROCK_SEED_FORM_ORB
	call _ecom_spawnProjectile
	ld bc,$1000
	call objectCopyPositionWithOffset
	jr @setAnimation0

@gotoNextSubstate:
	ld (hl),$0e
	ld l,Enemy.angle
	ld (hl),$18
	call _ecom_incSubstate

@setAnimation0:
	ld a,$00
	jp enemySetAnimation

_ramrock_seedPhase_substate3:
	ld e,Enemy.subid
	ld a,(de)
	cp $0e
	jr nz,_ramrock_seedPhase_resumeNormalMovement
	call _ramrock_updateHorizontalMovement
	ret nz

	call _ecom_incSubstate
	ld l,Enemy.counter1
	ld (hl),180
	inc l
	ld (hl),30 ; [counter2]

	ld b,PARTID_RAMROCK_SEED_FORM_LASER
	call _ecom_spawnProjectile
	ld l,Part.subid
	ld (hl),$0e
	ld bc,$0400
	jp objectCopyPositionWithOffset

; Firing energy beam
_ramrock_seedPhase_substate4:
	ld e,Enemy.subid
	ld a,(de)
	cp $0e
	jp nz,_ramrock_seedPhase_resumeNormalMovement

	call _ecom_decCounter2
	ret nz
	call _ecom_decCounter1
	jr z,@gotoNextSubstate

	ld a,(hl)
	and $07
	ld a,SND_SWORDBEAM
	call z,playSound
	jp _ramrock_updateHorizontalMovement

@gotoNextSubstate:
	call _ecom_incSubstate
	ld l,Enemy.counter1
	ld (hl),90
	ld l,Enemy.subid
	ld (hl),$0c

_ramrock_seedPhase_substate5:
	call _ecom_decCounter1
	ret nz
	jp _ramrock_seedPhase_resumeNormalMovement

_ramrock_seedPhase_substate6:
	ld e,Enemy.subid
	ld a,(de)
	cp $0f
	jr nz,++
	call _ecom_decCounter1
	ret nz
++
	jp _ramrock_seedPhase_6a94


; "Bomb" phase
_ramrock_glovePhase:
	inc e
	ld a,(de)
	rst_jumpTable
	.dw _ramrock_glovePhase_substate0
	.dw _ramrock_glovePhase_substate1
	.dw _ramrock_glovePhase_substate2
	.dw _ramrock_glovePhase_substate3
	.dw _ramrock_glovePhase_substate4

_ramrock_glovePhase_substate0:
	ld h,d
	ld bc,$4878
	ld l,Enemy.yh
	ldi a,(hl)
	cp b
	jr nz,@updateMovement

	inc l
	ld a,(hl)
	cp c
	jr nz,@updateMovement
	call _ecom_incSubstate

	ld bc,$e001
@spawnArm:
	push bc
	ld b,PARTID_RAMROCK_GLOVE_FORM_ARM
	call _ecom_spawnProjectile
	ld l,Part.subid
	ld (hl),c
	pop bc
	push bc
	ld c,b
	ld b,$18
	call objectCopyPositionWithOffset
	pop bc
	dec c
	ld a,$04
	jp nz,enemySetAnimation
	ld a,b
	cpl
	inc a
	ld b,a
	jr @spawnArm

@updateMovement:
	call objectGetRelativeAngle
	ld e,Enemy.angle
	ld (de),a
	jp objectApplySpeed

_ramrock_glovePhase_substate1:
	ld c,$10
	call objectUpdateSpeedZ_paramC
	ld e,Enemy.var37
	ld a,(de)
	cp $03
	ret nz
	call _ecom_incSubstate
	ld l,Enemy.counter2
	ld (hl),$02
	ld a,PALH_84
	jp loadPaletteHeader

_ramrock_glovePhase_substate2:
	call _ecom_decCounter2
	jr z,++
	ld a,SND_SWORD_OBTAINED
	call playSound
	ld a,PALH_83
	call loadPaletteHeader
++
	call enemyAnimate
	ld e,Enemy.animParameter
	ld a,(de)
	or a
	ret nz
	ld a,$03
	call enemySetAnimation

_ramrock_glovePhase_gotoSubstate3:
	ld bc,-$80
	call objectSetSpeedZ
	ld l,Enemy.subid
	ld (hl),$11
	ld l,Enemy.substate
	ld (hl),$03
	ld l,Enemy.angle
	ld (hl),$08
	ld l,Enemy.counter2
	ld (hl),120
	ret

_ramrock_glovePhase_substate3:
	call enemyAnimate
	ld e,Enemy.zh
	ld a,(de)
	cp $f9
	ld c,$00
	call nz,objectUpdateSpeedZ_paramC

	call _ramrock_glovePhase_updateMovement
	call _ecom_decCounter2
	jr nz,_ramrock_glovePhase_reverseDirection

	ld c,$50
	call objectCheckLinkWithinDistance
	jr nc,_ramrock_glovePhase_reverseDirection

	ld h,d
	ld l,Enemy.subid
	ld a,$12
	ldi (hl),a
	call getRandomNumber
	and $01
	swap a
	ld (hl),a
	call getRandomNumber
	and $0f
	jr nz,+
	set 5,(hl)
+
	ld l,Enemy.substate
	ld (hl),$04
	ret

_ramrock_glovePhase_substate4:
	ld e,Enemy.var35
	ld a,(de)
	cp $03
	jr z,@dead

	call enemyAnimate
	ld e,Enemy.var37
	ld a,(de)
	cp $03
	ret nz
	jr _ramrock_glovePhase_gotoSubstate3

@dead:
	ld e,Enemy.health
	xor a
	ld (de),a
	jp _enemyBoss_dead

;;
; Moves from side to side of the screen
_ramrock_updateHorizontalMovement:
	call _ecom_applyVelocityForSideviewEnemy
	ret nz
	ld e,Enemy.angle
	ld a,(de)
	xor $10
	ld (de),a
	xor a
	ret

_ramrock_glovePhase_reverseDirection:
	ld h,d
	ld l,Enemy.xh
	ld a,$c0
	cp (hl)
	jr c,++
	ld a,$28
	cp (hl)
	jr c,@applySpeed
	inc a
++
	ld (hl),a ; [xh]
	ld e,Enemy.angle
	ld a,(de)
	xor $10
	ld (de),a
	xor a
@applySpeed:
	jp objectApplySpeed

;;
_ramrock_glovePhase_updateMovement:
	ld hl,w1Link.yh
	ld e,Enemy.yh
	ld a,(de)
	cp (hl)
	jr nc,@label_10_262

	ld c,a
	ld a,(hl)
	sub c
	cp $40
	jr z,@ret
	jr c,@label_10_262

	ld a,(de)
	cp $50
	ld c,ANGLE_DOWN
	jr nc,@ret
	jr @moveInDirection

@label_10_262:
	ld a,(de) ; [yh]
	cp $41
	ld c,ANGLE_UP
	jr c,@ret

@moveInDirection:
	ld b,SPEED_80
	ld e,Enemy.angle
	call objectApplyGivenSpeed
@ret:
	ret


; ==============================================================================
; ENEMYID_KING_MOBLIN_MINION
;
; Variables:
;   relatedObj1: Instance of ENEMYID_KING_MOBLIN
;   relatedObj2: Instance of PARTID_BOMB (smaller bomb thrown by this object)
; ==============================================================================
enemyCode56_body:
	ld e,Enemy.state
	ld a,(de)
	rst_jumpTable
	.dw _kingMoblinMinion_state0
	.dw enemyAnimate
	.dw _kingMoblinMinion_state2
	.dw _kingMoblinMinion_state3
	.dw _kingMoblinMinion_state4
	.dw _kingMoblinMinion_state5
	.dw _kingMoblinMinion_state6
	.dw _kingMoblinMinion_state7
	.dw _kingMoblinMinion_state8
	.dw _kingMoblinMinion_state9
	.dw _kingMoblinMinion_stateA


_kingMoblinMinion_state0:
	ld h,d
	ld l,e
	inc (hl) ; [state] = 1

	ld l,Enemy.speed
	ld (hl),SPEED_200

	ld e,Enemy.subid
	ld a,(de)
	add a
	ld hl,@data
	rst_addDoubleIndex

	ld e,Enemy.counter1
	ldi a,(hl)
	ld (de),a
	ld e,Enemy.direction
	ldi a,(hl)
	ld (de),a
	ld e,Enemy.yh
	ldi a,(hl)
	ld (de),a
	ld e,Enemy.xh
	ld a,(hl)
	ld (de),a

	ld a,$02
	call enemySetAnimation
	jp objectSetVisiblec2

; Data format: counter1, direction, yh, xh
@data:
	.db  30, $03, $08, $18
	.db 150, $01, $08, $88



; Fight just started
_kingMoblinMinion_state2:
	ld h,d
	ld l,e
	inc (hl) ; [state] = 3

	ld l,Enemy.counter2
	ld (hl),$0c
	ld e,Enemy.direction
	ld a,(de)
	jp enemySetAnimation


; Delay before spawning bomb
_kingMoblinMinion_state3:
	call _ecom_decCounter2
	jr nz,_kingMoblinMinion_animate

	ld b,PARTID_BOMB
	call _ecom_spawnProjectile
	ret nz

	call _ecom_incState

	ld a,$02
	jp enemySetAnimation


; Holding bomb for a bit
_kingMoblinMinion_state4:
	call _ecom_decCounter1
	ld l,e
	jr z,@jump

	ld a,(wScreenShakeCounterY)
	or a
	jr z,_kingMoblinMinion_animate

	ld (hl),$07 ; [counter1]
	jr _kingMoblinMinion_animate

@jump:
	inc (hl) ; [state] = 5
	ld l,Enemy.speedZ
	ld a,<(-$180)
	ldi (hl),a
	ld (hl),>(-$180)

_kingMoblinMinion_animate:
	jp enemyAnimate


; Jumping in air
_kingMoblinMinion_state5:
	ld c,$20
	call objectUpdateSpeedZ_paramC
	jr z,@landed

	; Check for the peak of the jump
	ldd a,(hl)
	or (hl)
	ret nz

	call objectGetAngleTowardEnemyTarget
	ld b,a

	; [bomb.state]++
	ld a,Object.state
	call objectGetRelatedObject2Var
	inc (hl)

	; Set bomb to move toward Link
	ld l,Part.angle
	ld (hl),b
	ret

@landed:
	ld l,Enemy.state
	inc (hl) ; [state] = 6

	ld l,Enemy.counter1
	ld (hl),$10
	jr _kingMoblinMinion_animate


; Delay before pulling out next bomb
_kingMoblinMinion_state6:
	call _ecom_decCounter1
	jr nz,_kingMoblinMinion_animate

	ld (hl),200 ; [counter1]
	ld l,e
	ld (hl),$02 ; [state]

	jr _kingMoblinMinion_animate


; ENEMYID_KING_MOBLIN sets this object's state to 7 when defeated.
_kingMoblinMinion_state7:
	ld h,d
	ld l,e
	inc (hl) ; [state] = 8

	ld l,Enemy.counter1
	ld (hl),24

	; Calculate animation, store it in 'c'
	ld l,Enemy.subid
	ld a,(hl)
	add a
	inc a
	ld c,a

	; Get angle to throw bomb at
	ld a,(hl)
	ld hl,@subidBombThrowAngles
	rst_addAToHl
	ld b,(hl)

	ld a,Object.state
	call objectGetRelatedObject2Var
	inc (hl)

	ld l,Part.angle
	ld (hl),b

	ld l,Part.speed
	ld (hl),SPEED_160

	ld l,Part.speedZ
	ld a,<(-$100)
	ldi (hl),a
	ld (hl),>(-$100)

	ld l,Part.visible
	ld (hl),$81

	ld a,c
	jp enemySetAnimation

@subidBombThrowAngles:
	.db $0a $16


; Delay before hopping
_kingMoblinMinion_state8:
	call _ecom_decCounter1
	ret nz

	ld l,e
	inc (hl) ; [state] = 9

	ld l,Enemy.speedZ
	ld a,<(-$140)
	ldi (hl),a
	ld (hl),>(-$140)

	ld l,Enemy.subid
	bit 0,(hl)
	ld c,$f4
	jr z,+
	ld c,$0c
+
	ld b,$f8
	ld a,30
	call objectCreateExclamationMark


; Waiting to land on ground
_kingMoblinMinion_state9:
	ld c,$20
	call objectUpdateSpeedZ_paramC
	ret nz

	ld l,Enemy.state
	inc (hl) ; [state] = $0a

	ld l,Enemy.counter1
	ld (hl),12
	inc l
	ld (hl),$08 ; [counter2]

	xor a
	jp enemySetAnimation


; Running away
_kingMoblinMinion_stateA:
	call _ecom_decCounter2
	jr nz,@animate

	call _ecom_decCounter1
	jr z,@delete

	call objectApplySpeed
@animate:
	jp enemyAnimate

@delete:
	; Write to var33 on ENEMYID_KING_MOBLIN to request the screen transition to begin
	ld a,Object.var33
	call objectGetRelatedObject1Var
	ld (hl),$01
	jp enemyDelete


blackTower_getMovingFlamesNextTileCoords:
	ld e,$c2
	ld a,(de)
	ld hl,@table
	rst_addDoubleIndex
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	ld e,$c7
	ld a,(de)
	rst_addAToHl
	ld b,(hl)
	ld a,b
	and $f0
	add $08
	ld e,$f0
	ld (de),a
	inc e
	ld a,b
	and $0f
	swap a
	add $08
	ld (de),a
	ret

@table:
	.dw @leftFlame
	.dw @topFlame
	.dw @rightFlame
	.dw @bottomFlame

@leftFlame:
	.db $51 $91 $93 $13 $19 $39 $3d $9d
	.db $97 $77 $7a $8a $00

@topFlame:
	.db $17 $13 $73 $7d $3d $39 $99 $91
	.db $61 $62 $00

@rightFlame:
	.db $5d $9d $95 $55 $51 $11 $1b $3b
	.db $35 $25 $26 $00

@bottomFlame:
	.db $97 $99 $79 $7d $9d $9b $3b $3d
	.db $1d $1b $3b $35 $55 $53 $93 $98
	.db $88 $00