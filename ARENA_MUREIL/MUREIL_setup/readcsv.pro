pro readcsv,lons,lats,data,filename

lats = reverse(findgen(543) * 0.11 - (55.) )  ; need to check the offset if we're going the right way
lons = findgen(680) * 0.11 + 95.

nlats = n_elements(lats)
nlons = n_elements(lons)

data = fltarr(nlons,nlats)

openr,lun,filename,/get_lun

temp = ''

readf,lun,temp

ilat = 0

;while not EOF(lun) do BEGIN
for ilat = 0,nlats-1 do BEGIN
    temp2 = strsplit(temp,',',/EXTRACT)
    ;data(*,ilat) = float(temp2)
    data(*,ilat) = float(temp2(0:nlons-1))
    ;ilat = ilat + 1
    readf,lun,temp
;endwhile
endfor

free_lun,lun

;stop

end

