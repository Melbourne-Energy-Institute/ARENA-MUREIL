pro pixelplot,data,lons,lats,levs,colors

nlons = n_elements(lons)
nlats = n_elements(lats)
nlevs = n_elements(levs)

lons2 = lons - (lons(2)-lons(1))/2.
lats2 = lats + (lats(1)-lats(2))/1.

for i = 1,nlons-2 do BEGIN
    for j = 1,nlats-2 do BEGIN
        icol= data(i,j)
        color = colors(icol)
        ;print,data(i,j),lons(i),lats(j),data(i,j),color
        polyfill,[lons2(i),lons2(i+1),lons2(i+1),lons2(i),lons2(i)],[lats2(j),lats2(j),lats2(j+1),lats2(j+1),lats2(j)],color=color

        stop
    endfor
endfor

end
