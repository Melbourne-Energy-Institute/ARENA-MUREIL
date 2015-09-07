pro read_gens,name,capacity,ID,state,fuel1,fuel2,desc1,desc2,co2int

; read in the list of plants

name = strarr(500)
capacity = fltarr(500)
ID = strarr(500)
state = strarr(500)
fuel1= strarr(500)
fuel2 = strarr(500)
desc1 = strarr(500)
desc2 = strarr(500)
co2int = fltarr(500)

openr,lun,'AEMO_GENERATORS.csv',/get_lun

temp=''
readf,lun,temp
icount = 0
while not eof(lun) do BEGIN
    readf,lun,temp
    temp2 = strsplit(temp,',',/EXTRACT)
    npts = n_elements(temp2)
    if temp2(13) ne '-' then BEGIN ; no ID = not market dispatched

        name(icount) = temp2(1)
        state(icount) = temp2(2)
        fuel1(icount) = temp2(6)
        fuel2(icount) = temp2(7)
        desc1(icount) = temp2(8)
        desc2(icount) = temp2(9)
        ID(icount) = temp2(13)
        capacity(icount) = float(temp2(15))

        print,name(icount),ID(icount),capacity(icount),state(icount),fuel1(icount),fuel2(icount),format='(a20,10a10)'
        icount = icount + 1
    endif

endwhile

nstats = icount 

name = name(0:nstats-1)
state = state(0:nstats-1)
fuel1 = fuel1(0:nstats-1)
fuel2 = fuel2(0:nstats-1)
desc1 = desc1(0:nstats-1)
desc2 = desc2(0:nstats-1)
ID = ID(0:nstats-1)
capacity = capacity(0:nstats-1)

nstats = icount - 1

; now grab the emissions intensities

openr,lun,'Emission_Intensity.csv',/get_lun

temp=''
readf,lun,temp
readf,lun,temp
nametemp = strarr(400)
IDtemp = strarr(400)
co2int_temp = fltarr(400)
icount = 0
while not eof(lun) do BEGIN
    temp2 = strsplit(temp,',',/EXTRACT)
    nametemp(icount) = temp2(4)
    IDtemp(icount) = temp2(6)
    co2int_temp(icount) = temp2(8)

    ;print,temp2
    readf,lun,temp
    icount = icount + 1
endwhile

free_lun,lun

; now loop over the stations and find the co2 intensity where it exists

for i = 0,nstats-1 do BEGIN

    ;print,ID(i),' ',name(i),capacity(i)
    xx = where(IDtemp eq ID(i),nxx)
    if nxx gt 0 then co2int(i) = co2int_temp(xx)

    if nxx eq 0 then BEGIN 
        ;print,'No match for ',ID(i),name(i),capacity(i)
        ;if capacity(i) gt 100 then stop 
    endif

endfor

co2int = co2int(0:nstats-1)

end
