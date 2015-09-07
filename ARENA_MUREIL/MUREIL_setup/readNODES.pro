pro readnodes

nodes = ['NQ','CQ','SWQ','SEQ','NNSW','Hunter','Central','SYD','STHRN','CAN','SWNSW','NVIC','CVIC','LV','MEL','WVIC','SESA','ADE','NSA','FNSA','TAS']

; read in the NODE.csv file and generate the text for the config file

name = strarr(127)
ID = strarr(127)
type = strarr(127)
node = strarr(127)
year = intarr(127)
capacity = intarr(127)

name2 = strarr(127)
ID2 = strarr(127)
type2 = strarr(127)
node2 = strarr(127)
year2 = intarr(127)
capacity2 = intarr(127)

emission = fltarr(127)

; read in file

openr,lun,'NODES.csv',/get_lun

temp =''
readf,lun,temp
readf,lun,temp

for i= 0,126 do BEGIN
    readf,lun,temp
    temp2 = strsplit(temp,',',/EXTRACT)
    name(i) = temp2(1)
    ID(i) = temp2(2)
    type(i) = temp2(5)
    node(i) = temp2(17)
    year(i) = fix(temp2(7))
    capacity(i) = fix(temp2(16))
endfor
free_lun,lun

; Collapse down to single gens

counter = 0
for i = 0,126 do BEGIN
    mm = where(name eq name(i),nmm)

    if name(i) ne 'DONE' then BEGIN 

    name2(counter) = name(mm(0))
    ID2(counter) = ID(mm(0))
    year2(counter) = year(mm(0))
    type2(counter) = type(mm(0))
    node2(counter) = node(mm(0))
    capacity2(counter) = total(capacity(mm))

    name(mm) = 'DONE'

    counter = counter + 1

    endif
   
endfor

name2 = name2(0:counter-1)
ID2 = ID2(0:counter-1)
year2 = year2(0:counter-1)
type2 = type2(0:counter-1)
node2 = node2(0:counter-1)
capacity2 = capacity2(0:counter-1)


; fix PLAYFORD
   m = where(ID2 eq 'PLAYB-AG1')
   ID2(m(0)) = 'PLAYB-AG'
; fix PELICAN POINT
   m = where(ID2 eq 'PPCCGTGT1')
   ID2(m(0)) = 'PPCCGT'
; fix Townsville
   m = where(name2 eq 'Townsville')
   ID2(m(0)) = 'YABULU'
; fix DDPS1
   m = where(name2 eq 'Darling Downs')
   ID2(m(0)) = 'DDPS1'
; fix tamar
   m = where(name2 eq 'Tamar Valley CCGT')
   ID2(m(0)) = 'TVCC201'
; fix Yarwin
   m = where(name2 eq 'Yarwun CoGen')
    ID2(m(0)) = 'YARWUN_1'
; fix Colognra
   m = where(name2 eq 'Colongra GT')
    ID2(m(0)) = 'CG1'
; fix Mortlake
   m = where(name2 eq 'Mortlake')
    ID2(m(0)) = 'MORTLK11'
; fix Laverton
    m = where(name2 eq 'Laverton North')
    ID2(m(0)) = 'LAVNORTH'
; fix Uran
    m = where(name2 eq 'Uranquinty')
    ID2(m(0)) = 'URANQ11'
; fix Tamar OCGT
    m = where(name2 eq 'Tamar Valley OCGT')
    ID2(m(0)) = 'TVPP104'

read_emissions,ID_temp,co2int

for i = 0,counter-1 do BEGIN

    mm = where(ID_temp eq ID2(i),nmm)
    if nmm eq 0 then stop
    emission(i) = co2int(mm(0))
    print,ID2(i),name2(i),emission(i),node2(i),year2(i)
endfor

emission = emission(0:counter-1)

; adjust years2 to be nearest 5 year value

year2 = round(year2/5.)*5

; create text for CONFIG file

openw,lun,'CONGIF',/get_lun

brown = 0
black = 0
ocgt = 0
ccgt = 0

for i = 0,counter-1 do BEGIN

    if type2(i) eq 'Brown Coal' and year2(i) gt 1965 then BEGIN
        brown =brown + 1
        if brown ge 10 then printf,lun,'[BrownCoal_'+string(brown,format='(i2)')+']' else printf,lun,'[BrownCoal_'+string(brown,format='(i1)')+']'
        ;printf,lun,'model: thermal.txmultislowthermal.TxMultiSlowFixedThermal'
        printf,lun,'model: thermal.txmultiinstantthermal.TxMultiInstantFixedThermal'
        printf,lun,'capital_cost: 3.7'
        printf,lun,'fuel_price_mwh: 10'
        printf,lun,'carbon_intensity: '+string(emission(i),format='(f4.2)')
        printf,lun,'lifetime_yrs: 50'
        m = where(nodes eq node2(i))
        siteindex = i+3000
        printf,lun,'site_index: '+string(siteindex,format='(i4)')
        printf,lun,'startup_data_string: [['+string(siteindex,format='(i4)')+','+string(capacity2(i),format='(i4)')+','+string(year2(i),format='(i4)')+','+string(year2(i)+50,format='(i4)')+']]'
        ;printf,lun,'ramp_time_mins: 720'
        printf,lun,''
    endif
    if type2(i) eq 'Black Coal' and year2(i) gt 1965 then BEGIN
        black =black + 1
        if black ge 10 then printf,lun,'[BlackCoal_'+string(black,format='(i2)')+']' else printf,lun,'[BlackCoal_'+string(black,format='(i1)')+']'
        ;printf,lun,'model: thermal.txmultislowthermal.TxMultiSlowFixedThermal'
        printf,lun,'model: thermal.txmultiinstantthermal.TxMultiInstantFixedThermal'
        printf,lun,'capital_cost: 3.1'
        printf,lun,'fuel_price_mwh: 20'
        printf,lun,'carbon_intensity: '+string(emission(i),format='(f4.2)')
        printf,lun,'lifetime_yrs: 50'
        m = where(nodes eq node2(i))
        siteindex = i+4000
        printf,lun,'site_index: '+string(siteindex,format='(i4)')
        printf,lun,'startup_data_string: [['+string(siteindex,format='(i4)')+','+string(capacity2(i),format='(i4)')+','+string(year2(i),format='(i4)')+','+string(year2(i)+50,format='(i4)')+']]'
        ;printf,lun,'ramp_time_mins: 480'
        printf,lun,''
    endif
    if type2(i) eq 'OCGT' and year2(i) gt 1985 then BEGIN
        ocgt =ocgt + 1
        if ocgt ge 10 then printf,lun,'[OCGT_'+string(ocgt,format='(i2)')+']' else printf,lun,'[OCGT_'+string(ocgt,format='(i1)')+']'
        printf,lun,'model: thermal.txmultiinstantthermal.TxMultiInstantFixedThermal'
        printf,lun,'capital_cost: 0.7'
        printf,lun,'fuel_price_mwh: 61'
        printf,lun,'carbon_intensity: '+string(emission(i),format='(f4.2)')
        printf,lun,'lifetime_yrs: 30'
        m = where(nodes eq node2(i))
        siteindex = i+5000
        printf,lun,'site_index: '+string(siteindex,format='(i4)')
        printf,lun,'startup_data_string: [['+string(siteindex,format='(i4)')+','+string(capacity2(i),format='(i4)')+','+string(year2(i),format='(i4)')+','+string(year2(i)+30,format='(i4)')+']]'
        printf,lun,''
    endif

    if type2(i) eq 'CCGT' and year2(i) gt 1985 then BEGIN
        ccgt =ccgt + 1
        if ccgt ge 10 then printf,lun,'[CCGT_'+string(ccgt,format='(i2)')+']' else printf,lun,'[CCGT_'+string(ccgt,format='(i1)')+']'
        ;printf,lun,'model: thermal.txmultislowthermal.TxMultiSlowFixedThermal'
        printf,lun,'model: thermal.txmultiinstantthermal.TxMultiInstantFixedThermal'
        printf,lun,'capital_cost: 1.0'
        printf,lun,'fuel_price_mwh: 43'
        printf,lun,'carbon_intensity: '+string(emission(i),format='(f4.2)')
        printf,lun,'lifetime_yrs: 30'
        m = where(nodes eq node2(i))
        siteindex = i+6000
        printf,lun,'site_index: '+string(siteindex,format='(i4)')
        printf,lun,'startup_data_string: [['+string(siteindex,format='(i4)')+','+string(capacity2(i),format='(i4)')+','+string(year2(i),format='(i4)')+','+string(year2(i)+50,format='(i4)')+']]'
        ;printf,lun,'ramp_time_mins: 360'
        printf,lun,''
    endif

endfor

free_lun,lun

stop

; create the tx_connect_map.csv file

; each site needs to map onto a node

; loop through the wind and solar sites

; loop through the fossil sites



end

pro read_emissions,ID,co2int

; now grab the emissions intensities

openr,lun,'Emission_Intensity.csv',/get_lun

temp=''
readf,lun,temp
readf,lun,temp
nametemp = strarr(400)
ID = strarr(400)
co2int = fltarr(400)
icount = 0
while not eof(lun) do BEGIN
    temp2 = strsplit(temp,',',/EXTRACT)
    ID(icount) = temp2(6)
    co2int(icount) = temp2(8)
    readf,lun,temp
    icount = icount + 1
endwhile

free_lun,lun

ID = ID(0:icount-1)
co2int = co2int(0:icount-1)

end
