pro annualavs

; calculate annual average for DSR and u80

filename = '/mnt/meteo0/data/dargaville/rhuva/dsr_all-files.nc'

ncid=NCDF_OPEN(filename,/NOWRITE)
getvar,'lats',lats,filename
getvar,'lons',lons,filename

nlons = n_elements(lons)
nlats = n_elements(lats)

count = [nlons,nlats,1]

tots = fltarr(nlons,nlats)

counter = 0

for i = 0,17309 do BEGIN

    offset = [0,0,i]
    ncdf_varget,ncid,2,data,count=count,offset=offset

    if finite(max(data)) eq 1 then BEGIN
        tots = tots + data
        print,i
        counter = counter + 1
    endif

endfor

tots = tots/counter

ncdf_close,ncid

; write the output to a new file


filename='dsr_annualav.nc'
varname = 'dsr_annualav'
ncid = NCDF_CREATE(filename,/CLOBBER)
xdimid = NCDF_DIMDEF(ncid,'lons',nlons)
if (xdimid eq -1) then stop,'error'
ydimid = NCDF_DIMDEF(ncid,'lats',nlats)
if (ydimid eq -1) then stop,'error'

xid = NCDF_VARDEF(ncid,'lons',xdimid)
yid = NCDF_VARDEF(ncid,'lats',ydimid)
dims = [xdimid,ydimid]
print,'dims = ',dims
dataid = NCDF_VARDEF(ncid,varname,dims)

NCDF_control,ncid,/endef

NCDF_VARPUT,ncid,xid,lons
NCDF_VARPUT,ncid,yid,lats
print,'in WRITENC ',ncid,dataid
NCDF_VARPUT,ncid,dataid,tots

NCDF_CLOSE, ncid

stop

end
