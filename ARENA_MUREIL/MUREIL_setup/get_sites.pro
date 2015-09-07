pro get_sites

; Melbourne coords
lat = -37.80
lon = 144.96

; St Lucia
lat = -27.498
lon = 153.011858

solarfile = '/mnt/meteo0/data/dargaville/rhuva/ACCESS/dsr_complete.nc'
solarfile = '/mnt/meteo0/data/dargaville/rogerd/ACCESS-A/dsr_complete_all-ACCESS.nc'

getvar,'lons',lons,'dsr_annualav.nc'
getvar,'lats',lats,'dsr_annualav.nc'
lats = lats - 0.11

diff = (lons-lon)^2
ilon = where(diff eq min(diff),nii)
if nii ne 1 then stop
ilon = ilon(0)
diff = (lats-lat)^2
ilat = where(diff eq min(diff),nii)
if nii ne 1 then stop
ilat = ilat(0)

print,lons(ilon)
print,lats(ilat)

getvarsite,'dsr',data,solarfile,ilon,ilat

time = dindgen(n_elements(data))/24. + julday(1,1,2010) - 3/24.

writets,'ACCESS_solar','Incoming total downward shortwave radiation (W/m2), from BoM ACCESS model output',time,data

stop

end



