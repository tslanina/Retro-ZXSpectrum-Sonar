; Sonar
;
; 256 bytes intro for ZX Spectrum by Tomasz Slanina ( dox/joker )
; 4th place ( 256b oldskool, Lovebyte 2k23)
;
; https://github.com/tslanina


COLOR_STANDARD equ 4 + 64
COLOR_MISSILE  equ 2 + 64

        org $f800

        db 0,   %00010000   ; a period
        db 1,   %00000001   ; a period (coarse)
.mixer:      
        db 7,   %00111110   ; mixer 
        db 8,   %00011111   ; amp a
        db 12,  %00111111   ; env period
        db 13,  0           ; env shape (one shot)
     
     
start:
        di ; +2a/+3 fix (mem clear affects system variables (bank))
        
        ld ix,$5800+4 ; missile start pos
        ld hl,$5800

.clrloop:
        ld [hl],COLOR_STANDARD
        inc hl
        bit 7,h
        jr z,.clrloop   ; clear/fill 

.restart:   
        xor a
        out [254],a     ; black border
        ld sp,$8400+2   ; top of point buffer
        ld d,a
        ld e,a ; de = 0,0 = start point

.setdir:
        ld a,1 ; generate table with point coords (x,y) in  RAM
        xor l
        ld l,a
        cpl
 
        ld h,a ;hl  = dx dy

        ld a,r  ; a little bit of pseudo random ... the 'formula' of point gen can be simplified/optmized/whatever .. but it works, so ;)
        xor %1010
        and %1111
        inc a
        ld b,a

.deloop:
        dec b
        jr z,.setdir

        push de ; save coords

        ld a,d
        xor e
        cpl
        ld d,a

        ; -x, y

        push de ; save coords
        push hl ; dx dy on stack ( in the table in fact ...)

        add hl,de
        ex de,hl  ; x+dx, y+dy  ; move to next point

        ld hl,0   ; check the sp

        add hl,sp
        bit 7,h   ; stack below $8000 ; >$400/2 points generated, enough ;)
        pop hl
        jr nz,.deloop

        ld h,$84    ; end of point table

        ld b,h 

 .rotate:

        push bc
        push hl

        ld a,b
        and %11111
        jr nz,.nopix


        ld [ix],COLOR_STANDARD
        ld bc,33    ; next line + next cell
        add ix,bc


        ld a,ixl
        cp $6f  ; center of screen = hit
        jr nz,.notend

        ld a,-15
        ld [.nextmod+1],a  ; end = no loop

        ld a, %00110111 ; tune -> noise
        ld [.mixer+1],a 

.notend :
        ld de,$f800 ; audio data

.beep:  
        ld bc,255*256+253
        ld a,[de]

        inc e
        out (c),a
        ld b,191
        ld a,[de]
        out (c),a
        inc e
        or a
        jr nz,.beep

.nopix:
        ld [ix],COLOR_MISSILE

        push ix
        pop de

        ld a,d ; attribute -> pixel
        and 3
        rlca
        rlca
        rlca
        or $40
        ld d,a
        ld a,%00111100  ; misssile gfx

        ld [de],a
        inc d
        ld [de],a
        inc d
        ld [de],a
        inc d
        ld [de],a


        ; main loop : get point coords form table -> put on screen -> rotate -> update table

.pointloop:
        
        ld e,[hl] ; next point from the tab
        dec hl
        ld d,[hl]

        push de
        push hl

        ;x,y (0,0 @ center of screen) to speccy screen coords

        ld a,e
        add a,128

        ld e,a

        srl a
        srl a
        sub e
        cpl

        ld e,a

        ld a,d
        add a,128
        ld d,a

        ld a,3
        and d
        ld b,a
        inc b

        ld a,e
        rra
        scf
        rra
        or a
        rra
        ld l,a
        xor e
        and 248
        xor e
        ld h,a
        ld a,d
        xor l
        and 7
        xor d
        rrca
        rrca
        rrca
        ld l,a
        ld a,7 ; 3 bit wide pixel at start

 .pixrot:
        rrca
        rrca
        djnz .pixrot

        or [hl]     
        ld [hl],a ; draw on screen

        pop hl
        pop de; back to table with x,y  (hl)  and pixel coords (de)


        ; basically a very simplified point rotation sin/cos formula, fixed angle, low precision, errors accumulate witch each iteration and points move off-center  (tbh it's  the clou of the effect ;)

        ld a,e
        sra a
        sra a
        sra a
        sub d
        cpl
        
        ld[hl],a ;new x calced
        ld a,d
        sra a
        sra a
        sra a
        add a,e

        ;end of rotate
 
        inc hl
        ld [hl],a ;new y calced
        dec hl
        dec hl

        bit 7, h
        jp nz, .pointloop

        ; process whole scren (clar-like)

        ld h,$3f;  hl = $3fff 
.process:
        srl [hl]
        inc hl
        sla [hl]
        inc hl
        ld a,h
        cp $58
        jr nz,.process

.nextmod:

        jr .next    ; modified later

.next:        
        pop hl
        pop bc
        dec b
        jp nz, .rotate

        jp .restart ; generate new points

end start