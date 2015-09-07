pro pixelplot,data,lons,lats,levs,colors

nlons = n_elements(lons)
nlats = n_elements(lats)
nlevs = n_elements(levs)

; offset lats and lons - minus half a lon and a whole latitude
;lons2 = lons - (lons(2)-lons(1))/2.
;lats2 = lats + (lats(1)-lats(2))/1.

lons2 = lons
lats2 = lats

for i = 1,nlons-2 do BEGIN
    for j = 1,nlats-2 do BEGIN
        ; which level are we closest to?
        diff = (data(i,j) - levs)^2
        icol = reform(where(diff eq min(diff)))
        ;icol= data(i,j)
        color = reform(colors(icol))
        color = color(0)
        ;print,data(i,j),lons(i),lats(j),data(i,j),color
        polyfill,[lons2(i),lons2(i+1),lons2(i+1),lons2(i),lons2(i)],[lats2(j),lats2(j),lats2(j+1),lats2(j+1),lats2(j)],color=color

;        stop
    endfor
endfor

end
