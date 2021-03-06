.ifdef BUILD_VANILLA

; From here on are corrupted repeats of functions starting from
; "readParametersForRectangleDrawing".

;;
_fake_readParametersForRectangleDrawing:
	ldi a,(hl)
	ld b,a
	ldi a,(hl)
	ld c,a
	ret

;;
_fake_drawRectangleToVramTiles_withParameters:
	ld a,($ff00+R_SVBK)
	push af
	ld a,$03
	ld ($ff00+R_SVBK),a
	jr _fake_drawRectangleToVramTiles@nextRow

;;
_fake_drawRectangleToVramTiles:
	ld a,($ff00+R_SVBK)
	push af
	ld a,$03
	ld ($ff00+R_SVBK),a
	call $7de3

@nextRow:
	push bc
--
	ldi a,(hl)
	ld (de),a
	set 2,d
	ldi a,(hl)
	ld (de),a
	res 2,d
	inc de
	dec c
	jr nz,--

	pop bc
	ld a,$20
	sub c
	call addAToDe
	dec b
	jr nz,@nextRow

	pop af
	ld ($ff00+R_SVBK),a
	ret

;;
_fake_copyRectangleFromVramTilesToAddress_paramBc:
	ld l,c
	ld h,b

;;
_fake_copyRectangleFromVramTilesToAddress:
	ld a,($ff00+R_SVBK)
	push af

	ldi a,(hl)
	ld b,a
	ldi a,(hl)
	ld c,a
	ldi a,(hl)
	ld e,a
	ldi a,(hl)
	ld d,a
	ldi a,(hl)
	ld h,(hl)
	ld l,a

@nextRow:
	push bc
--
	ld a,$02
	ld ($ff00+R_SVBK),a
	ldi a,(hl)
	ld b,a
	ld a,$03
	ld ($ff00+R_SVBK),a
	ld a,b
	ld (de),a
	inc de
	dec c
	jr nz,--
	pop bc
	ld a,$20
	sub c
	call addAToDe
	ld a,$20
	sub c
	rst_addAToHl
	dec b
	jr nz,@nextRow

	pop af
	ld ($ff00+R_SVBK),a
	ret

;;
_fake_copyRectangleToRoomLayoutAndCollisions:
	ldi a,(hl)
	ld e,a
	ldi a,(hl)
	ld d,a

;;
_fake_copyRectangleToRoomLayoutAndCollisions_paramDe:
	ldi a,(hl)
	ld b,a
	ldi a,(hl)
	ld c,a

@nextRow:
	push bc
--
	ldi a,(hl)
	ld (de),a
	dec d
	ldi a,(hl)
	ld (de),a
	inc d
	inc de
	dec c
	jr nz,--
	pop bc
	ld a,$10
	sub c
	call addAToDe
	dec b
	jr nz,@nextRow
	ret

;;
_fake_roomTileChangesAfterLoad04:
	ld hl,wInShop
	set 1,(hl)
	ld a,TREE_GFXH_03
	jp $1686

;;
_fake_checkLoadPastSignAndChestGfx:
	ld a,(wDungeonIndex)
	cp $0f
	ret z

	ld a,(wTilesetFlags)
	bit 7,a
	ret z

	bit 0,a
	ret nz

	bit 5,a
	ret nz

	and $1c
	ret z

	ld a,UNCMP_GFXH_AGES_37
	jp $05df

_fake_rectangleData_02_7de1:
	.db $06 $06
	.dw w3VramTiles+8 w2TmpGfxBuffer

.endif ; BUILD_VANILLA
