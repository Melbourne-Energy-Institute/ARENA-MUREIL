import cPickle 
import numpy as np
import pupynere as nc

dir = '/home/UNIMELB/rogerd/MUREIL/'
file = 'temp'

f = open(dir+file+'.pkl', 'r')
p = cPickle.Unpickler(f)
data = p.load()

best_gene_data = data['best_gene_data']
totcost = [0]
for i in range(len(best_gene_data)):
    totcost.append(best_gene_data[i][1])

niterations = len(totcost)

ts_demand = data['ts_demand']

best_results = data['best_results']

capacity = best_results['capacity']
cost = best_results['cost']
wind_capacity = capacity['wind']
solar_capacity = capacity['solar']
browncoal_capacity = capacity['browncoal']
blackcoal_capacity = capacity['blackcoal']
ocgtgas_capacity = capacity['ocgtgas']
ccgtgas_capacity = capacity['ccgtgas']

output = best_results['output']
wind_out = output['wind']
solar_out = output['solar']
hydro_out = output['hydro']
ocgtgas_out = output['ocgtgas']
ccgtgas_out = output['ccgtgas']
browncoal_out = output['browncoal']
blackcoal_out = output['blackcoal']

nstations_w = len(wind_capacity)
nstations_s = len(solar_capacity)
nsteps = len(wind_out)

#Write to netcdf file:

o = nc.netcdf_file(file+'.nc', 'w')

o.createDimension('nstations_wind', nstations_w)
o.createDimension('nstations_solar', nstations_s)
o.createDimension('nsteps', nsteps)
o.createDimension('niterations', niterations)


wind_output = o.createVariable("ts_wind", 'f', ('nsteps',))
solar_output = o.createVariable("ts_solar", 'f', ('nsteps',))
hydro_output = o.createVariable("ts_hydro", 'f', ('nsteps',))
ocgtgas_output = o.createVariable("ts_ocgtgas", 'f', ('nsteps',))
ccgtgas_output = o.createVariable("ts_ccgtgas", 'f', ('nsteps',))
browncoal_output = o.createVariable("ts_browncoal", 'f', ('nsteps',))
blackcoal_output = o.createVariable("ts_blackcoal", 'f', ('nsteps',))
demand_output = o.createVariable("ts_demand", 'f', ('nsteps',))

wind_cap = o.createVariable("wind_cap", 'f', ('nstations_wind',))
solar_cap = o.createVariable("solar_cap", 'f', ('nstations_solar',))

best_gene_out = o.createVariable("best_gene_out", 'f', ('niterations',))

wind_output[:] = wind_out
solar_output[:] = solar_out
hydro_output[:] = hydro_out
ocgtgas_output[:] = ocgtgas_out
ccgtgas_output[:] = ccgtgas_out
browncoal_output[:] = browncoal_out
blackcoal_output[:] = blackcoal_out
demand_output[:] = ts_demand

wind_cap[:] = wind_capacity
solar_cap[:] = solar_capacity
#browncoal_cap[:] = browncoal_capacity
#blackcoal_cap[:] = blackcoal_capacity

best_gene_out[:] = totcost

wind_output.cost = cost['wind']
solar_output.cost = cost['solar']
browncoal_output.cost = cost['browncoal']
blackcoal_output.cost = cost['blackcoal']
ocgtgas_output.cost = cost['ocgtgas']
ccgtgas_output.cost = cost['ccgtgas']
hydro_output.cost = cost['hydro']

wind_output.capacity = capacity['wind']
solar_output.capacity = capacity['solar']
browncoal_output.capacity = capacity['browncoal']
blackcoal_output.capacity = capacity['blackcoal']
ocgtgas_output.capacity = capacity['ocgtgas']
ccgtgas_output.capacity = capacity['ccgtgas']
hydro_output.capacity = capacity['hydro']

o.close()


