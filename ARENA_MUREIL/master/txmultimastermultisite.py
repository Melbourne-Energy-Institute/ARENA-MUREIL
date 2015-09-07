#
#
# Copyright (C) University of Melbourne 2012
#
#
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.
#
#
import numpy
import time
import logging
import copy
from os import path

from tools import mureilbuilder, mureilexception, mureiloutput, mureiltypes, globalconfig
from tools import mureilbase, configurablebase

from generator import txmultigeneratorbase

logger = logging.getLogger(__name__)

class TxMultiMasterMultiSite(mureilbase.MasterInterface, configurablebase.ConfigurableMultiBase):
    def get_full_config(self):
        if not self.is_configured:
            return None
        
        # Will return configs collected from all objects, assembled into full_config.
        full_conf = {}
        full_conf['Master'] = self.config
        full_conf[self.config['data']] = self.data.get_config()
        full_conf[self.config['algorithm']] = self.algorithm.get_config()
        full_conf[self.config['global']] = self.global_config

        for gen_type in self.dispatch_order:
            full_conf[self.config[gen_type]] = self.gen_list[gen_type].get_config()

        return full_conf

     
    def set_config(self, full_config, extra_data):
    
        # Master explicitly does not copy in the global variables. It is too confusing
        # to combine those with flags, defaults and values defined in the config files.
        self.load_initial_config(full_config['Master'])
        
        # Get the global variables
        mureilbuilder.check_section_exists(full_config, self.config['global'])
        if 'model' not in full_config[self.config['global']]:
            full_config[self.config['global']]['model'] = 'tools.globalconfig.GlobalBase'
        self.global_calc = mureilbuilder.create_instance(full_config, None, self.config['global'], 
            mureilbase.ConfigurableInterface)    
        self.global_config = self.global_calc.get_config()

        # Now check the dispatch_order, to get a list of the generators
        for gen in self.config['dispatch_order']:
            self.config_spec += [(gen, None, None)]

        self.update_from_config_spec()
        self.check_config()
        
        self.dispatch_order = self.config['dispatch_order']
        self.pre_transmission_dispatch = self.config['pre_transmission_dispatch']
        
        # Set up the data class and get the data, and compute the global parameters
        self.data = mureilbuilder.create_instance(full_config, self.global_config, self.config['data'], 
            mureilbase.DataSinglePassInterface)
        self.global_calc.update_config({'data_ts_length': self.data.get_ts_length()})
        self.global_calc.post_data_global_calcs()
        self.global_config = self.global_calc.get_config()

        # Instantiate the transmission model
        if self.config['transmission'] in full_config:
            self.transmission = mureilbuilder.create_instance(full_config, self.global_config, 
                self.config['transmission'], configurablebase.ConfigurableMultiBase,
                self.config['run_periods'])
            mureilbuilder.supply_single_pass_data(self.transmission,
                self.data, self.config['transmission'])
        else:
            self.transmission = None
        
        # Instantiate the generator objects, set their data, determine their param requirements
        param_count = 0
        self.gen_list = {}
        self.gen_params = {}
        
        start_values_min = numpy.array([[]]).reshape((len(self.config['run_periods']), 0))
        start_values_max = numpy.array([[]]).reshape((len(self.config['run_periods']), 0))

        for i in range(len(self.dispatch_order)):
            gen_type = self.dispatch_order[i]

            # Build the generator instances
            gen = mureilbuilder.create_instance(full_config, self.global_config, 
                self.config[gen_type], txmultigeneratorbase.TxMultiGeneratorBase,
                self.config['run_periods'])
            self.gen_list[gen_type] = gen

            # Supply data as requested by the generator
            mureilbuilder.supply_single_pass_data(gen, self.data, gen_type)
    
            # Determine how many parameters this generator requires and
            # allocate the slots in the params list
            params_req = gen.get_param_count()
            if (params_req == 0):
                self.gen_params[gen_type] = (0, 0)
            else:
                self.gen_params[gen_type] = (param_count, 
                    param_count + params_req)

                run_period_len = len(self.config['run_periods'])
                (starts_min, starts_max) = gen.get_param_starts()
                starts_min = numpy.array(starts_min)
                starts_max = numpy.array(starts_max)

                if starts_min.size == 0:
                    start_values_min = numpy.hstack((start_values_min, (
                        (numpy.ones((run_period_len, params_req)) * 
                        self.global_config['min_param_val']).tolist())))
                else:
                    start_values_min = numpy.hstack((start_values_min, starts_min))

                if starts_max.size == 0:
                    start_values_max = numpy.hstack((start_values_max, (
                        (numpy.ones((run_period_len, params_req)) * 
                        self.global_config['max_param_val']).tolist())))
                else:
                    start_values_max = numpy.hstack((start_values_max, starts_max))

            param_count += params_req

        start_values_min = start_values_min.reshape(run_period_len * param_count)
        start_values_max = start_values_max.reshape(run_period_len * param_count)

        self.param_count = param_count
        # Check that run_periods increases by time_period_yrs
        self.run_periods = self.config['run_periods']
        if len(self.run_periods) > 1:
            run_period_diffs = numpy.diff(self.run_periods)
            if (not (min(run_period_diffs) == self.global_config['time_period_yrs']) or
                not (max(run_period_diffs) == self.global_config['time_period_yrs'])):
                raise mureilexception.ConfigException('run_periods must be separated by time_period_yrs', {})

        self.period_count = len(self.run_periods)
        self.total_param_count = param_count * self.period_count

        # Check if 'extra_data' has been provided, as a full gene to start at.
        # extra_data needs to be a dict with entry 'start_gene' that is a list
        # of integer values the same length as param_count.
        if extra_data is not None:
            if 'start_gene' in extra_data:
                if not (len(start_values_min) == self.total_param_count):
                    msg = ('extra_data of start_gene passed to txmultimastersimple. ' +
                        'Length expected = {:d}, found = {:d}'.format(self.total_param_count, 
                        len(start_values_min)))
                    raise mureilexception.ConfigException(msg, {})

                start_values_min = extra_data['start_gene']
                start_values_max = extra_data['start_gene']
       
        # Instantiate the genetic algorithm
        mureilbuilder.check_section_exists(full_config, self.config['algorithm'])
        algorithm_config = full_config[self.config['algorithm']]
        algorithm_config['min_len'] = algorithm_config['max_len'] = self.total_param_count
        algorithm_config['start_values_min'] = start_values_min
        algorithm_config['start_values_max'] = start_values_max
        algorithm_config['gene_test_callback'] = self.gene_test
        self.algorithm = mureilbuilder.create_instance(full_config, self.global_config,
            self.config['algorithm'], mureilbase.ConfigurableInterface)

        self.is_configured = True
    
    
    def get_config_spec(self):
        """Return a list of tuples of format (name, conversion function, default),
        e.g. ('capex', float, 2.0). Put None if no conversion required, or if no
        default value, e.g. ('name', None, None)

        Configuration:
            algorithm: The name of the configuration file section specifying the algorithm class to use and
                its configuration parameters. Defaults to 'Algorithm'.
            data: The name of the configuration file section specifying the data class to use and its
                configuration parameters. Defaults to 'Data'.
            transmission: The name of the configuration file section specifying the transmission model class
                to use and its configuration parameters. Defaults to 'Transmission', and if the 'Transmission'
                section is not provided, no transmission model will be used.
            global: The name of the configuration file section specifying the global configuration parameters.
                Defaults to 'Global'.

            dispatch_order: a list of strings specifying the names of the generator models to dispatch, in order,
                to meet the demand. All of these models then require a parameter defining the configuration file 
                section where they are configured. e.g. dispatch_order: solar wind gas. This requires additional
                parameters, for example solar: Solar, wind: Wind and gas: Instant_Gas to be defined, and corresponding
                sections Solar, Wind and Instant_Gas to configure those models.
                
            pre_transmission_dispatch: A list of strings specifying the names of the generator models to dispatch
                before calculating the transmission constraints. This is just for this version of the transmission
                model. Generally it here contains the renewable energies, since these are non-dispatchable. The algorithm
                therefore can directly alter the generation by changing capacity values.                 

            run_periods: A list of integers specifying the years defining each period in the multi-period
                simulation. Defaults to 2010. e.g. run_periods: 2010 2020 2030 2040 2050

            iterations: The number of iterations of the algorithm to execute. Defaults to 100.

            output_file: The filename to write the final output data to. Defaults to 'mureil.pkl'.
            output_frequency: Defaults to 500. After the first iteration and every output_frequency after
                that, report on the simulation status.
            do_plots: Defaults to False. If True, output plots every output_frequency and at the end
                of the run.
        """
        return [
            ('algorithm', None, 'Algorithm'),
            ('data', None, 'Data'),
            ('transmission', None, 'Transmission'),
            ('global', None, 'Global'),
            ('iterations', int, 100),
            ('output_file', None, 'mureil.pkl'),
            ('dispatch_order', mureilbuilder.make_string_list, None),
            ('pre_transmission_dispatch', mureilbuilder.make_string_list, None),
            ('do_plots', mureilbuilder.string_to_bool, False),
            ('output_frequency', int, 500),
            ('run_periods', mureilbuilder.make_int_list, [2010])
            ]


    def run(self, extra_data=None):
        start_time = time.time()
        logger.critical('Run started at %s', time.ctime())

        if (not self.is_configured):
            msg = 'run requested, but txmultimastersimple is not configured'
            logger.critical(msg)
            raise mureilexception.ConfigException(msg, {})
    
        try:
            self.algorithm.prepare_run()
            for i in range(self.config['iterations']):
                self.algorithm.do_iteration()
                if ((self.config['output_frequency'] > 0) and
                    ((i % self.config['output_frequency']) == 0)):
                    logger.info('Interim results at iteration %d', i)
                    self.output_results(iteration=i)
                    
        except mureilexception.AlgorithmException:
            # Insert here something special to do if debugging
            # such an exception is required.
            # self.finalise will be called by the caller
            raise
    
        logger.critical('Run time: %.2f seconds', (time.time() - start_time))

        results = self.output_results(iteration=self.config['iterations'], final=True)
        
        return results
    
    
    def output_results(self, final=False, iteration=0):
    
        (best_params, opt_data) = self.algorithm.get_final()

        if len(best_params) > 0:
            # Protect against an exception before there are any params
            results = self.evaluate_results(best_params)

            logger.info('======================================================')
            logger.info('Total cost ($M): {:.2f}, including carbon (MT): {:.2f}, terminal value ($M): {:.2f}'.format(
                results['totals']['cost'], results['totals']['carbon'] * 1e-6, results['totals']['terminal_value']))
            logger.info('======================================================')

            ts_demand = {}
    
            # Now iterate across the periods, and then across the generators
            for period in self.run_periods:
                period_results = results['periods'][period]
                logger.info('------------------------------------------------------')
                logger.info('PERIOD ' + str(period) + ':')
                logger.info('------------------------------------------------------')
                logger.info('Period cost ($M): {:.2f}, carbon (MT): {:.2f}'.format(
                    period_results['totals']['cost'], 
                    period_results['totals']['carbon'] * 1e-6))
                
                if self.transmission is not None:
                    logger.info('Total penalty for missed transmission ($M): {:.2f}, for missed flow of (MWh): {:.2f}'.format(
                        period_results['totals']['tx_cost'], period_results['totals']['tx_cost']/self.transmission.penalty_failed_transmission))
 
                if 'demand' in self.dispatch_order:
                    ts_demand[period] = period_results['generators']['demand']['other']['ts_demand']
                else:
                    ts_demand[period] = self.data.get_timeseries('ts_demand')
                period_results['totals']['demand'] = (numpy.sum(ts_demand[period]) *
                    self.global_config['time_scale_up_mult'] * self.global_config['timestep_hrs'])
                logger.info('Period total demand (GWh): {:.2f}'.format(
                    period_results['totals']['demand'] / 1000))

                for gen_type, value in period_results['generators'].iteritems():
                    gen_string = value['desc_string']
                    gen_cost = value['cost']
                    gen_supply = value['total_supply_period']
                    logger.info(gen_type + ' ($M {:.2f}, GWh {:.2f}) : '.format(
                        gen_cost, gen_supply / 1000) + gen_string)

            logger.info('======================================================')

            pickle_dict = {}
            pickle_dict['opt_data'] = opt_data
            pickle_dict['best_params'] = best_params

            full_conf = self.get_full_config()
            mureiloutput.clean_config_for_pickle(full_conf)
            pickle_dict['config'] = full_conf

            pickle_dict['best_results'] = results
            pickle_dict['ts_demand'] = ts_demand

            if self.config['do_plots']:
                for period in self.run_periods:
                    plot_data = {}
                    for gen_type, value in results['periods'][period]['generators'].iteritems():
                        plot_data[gen_type] = value['aggregate_supply']
                        
                    this_final = final and (period == self.config['run_periods'][-1])
                    mureiloutput.plot_timeseries(plot_data, 

                        ts_demand[period], this_final, plot_title=(

                            str(period) + ' at iteration ' + str(iteration)))

            output_file = self.config['output_file']
            mureiloutput.pickle_out(pickle_dict, output_file)
        else:
            results = None

        return results
        

    def finalise(self):
        self.algorithm.finalise()

            
    def calc_cost(self, gene):
        """Calculate the total system cost for this gene. This function is called
        by the algorithm from a callback. The algorithm may set up multi-processing
        and so this calc_cost function (and all functions it calls) must be
        thread-safe. 
        This means that the function must not modify any of the 
        internal data of the objects. 
        """
        temp = numpy.array(gene)
        params_set = temp.reshape(self.period_count, self.param_count)

        gen_state_handles = {}
        for gen_type in self.dispatch_order:
            gen_state_handles[gen_type] = (
                self.gen_list[gen_type].get_startup_state_handle())        

        if self.transmission is not None:
            tx_state_handle = self.transmission.get_startup_state_handle()

        results = {'totals': {}, 'periods': {}, 'terminal': {}}
                
        cost = 0
        total_carbon = 0.0

#        start = time.time()
               
        for i in range(len(self.run_periods)):
            period = self.run_periods[i]
            params = params_set[i]

            period_carbon = 0.0
            period_cost = 0
            
            results['periods'][period] = period_results = {'generators': {}, 'totals': {}}
            results['terminal'] = {'totals': {}, 'generators': {}}

            # supply_request is the time series of demand
            # TODO: put in demand model that distributes the
            # the demand over the network, as soon as demand model exists.
            # right now, use just a single demand value for each timeseries, which
            # will be put in node 5 for now
            supply_request = numpy.array(self.data.get_timeseries('ts_demand'), dtype=float)
            # generate a copy, to cross-check in transmission model
            orig_supply = supply_request            
            
    
            if self.transmission is not None:
                # tx_supply_request is the part of the demand, that is being checked by the transmission network
                # tx_supply_request is positive and will later be substracted from supply matrix
                tx_supply_request = numpy.zeros(supply_request.shape)
                
                # Create an empty supply_request matrix for the transmission model to work with.
                # the rows relating to nodes used as a renewable site or as a demand site will be 
                # changed later, other nodes stay zero 
                # tx_supply is positiv for a generation in node, negative for a demand
                tx_supply = numpy.zeros((self.data.no_nodes, self.data.get_ts_length()))
                
            # First calculate non-dispatchables supply
            # site indices are nodes of the transmission network, this could be changed, if
            # for example several sites connect to one node of the network. This must then be done
            # with a map (as a parameter given in the data or config) and used when filling the 
            # rows of the empty supply_request array
            for gen_type in self.pre_transmission_dispatch:
                gen = self.gen_list[gen_type]
                gen_ptr = self.gen_params[gen_type]

                gen_cost = 0        #cost for this generator in this period
                gen_carbon = 0.0    #carbon for this generator in this period
                
                period_results['generators'][gen_type] = gen.calculate_time_period_full( 
                        gen_state_handles[gen_type], period, params[gen_ptr[0]:gen_ptr[1]], 
                        supply_request, make_string=True, do_decommissioning = False)

                        
                #substract from supply_request
                # but add to tx_supply_request for transmission model
                temp_gen_supply_sum = numpy.sum(period_results['generators'][gen_type]['supply'], 0)
                supply_request -= temp_gen_supply_sum
                
                if self.transmission is not None:
                    tx_supply_request += temp_gen_supply_sum
                    # add supply for each site to supply matrix, that is used for 
                    # the transmission model                    
                    for idx, site in enumerate(period_results['generators'][gen_type]['site_indices']):
                        tx_supply[site] += period_results['generators'][gen_type]['supply'][idx]
                
                ## TODO: one liner for sum possible I think
                gen_cap_cost = 0
                for idx, value in enumerate(period_results['generators'][gen_type]['new_capacity']):
                    gen_cap_cost += value[2]
                
                # Add up costs, installation, var. cost    
                gen_cost += gen_cap_cost
                gen_cost += numpy.sum(period_results['generators'][gen_type]['variable_cost_ts'])
                gen_carbon += numpy.sum(period_results['generators'][gen_type]['carbon_emissions_ts'])
                period_cost += gen_cost   
                period_carbon += gen_carbon   
                
                # add cost and total supply of generator into results
                period_results['generators'][gen_type]['new_capacity_cost'] = gen_cap_cost
                period_results['generators'][gen_type]['cost'] = gen_cost
                period_results['generators'][gen_type]['total_supply_period'] = numpy.sum(period_results['generators'][gen_type]['supply'])
                                

            if self.transmission is not None:
#                start_tx = time.time()
                
                # Routine, that if there is more total supply by the non-dispatchables than total
                # demand, to curtail some sites of renewables, this is not ideal, but transmission 
                # model will otherwise just dump everything in node 0 and give back a high penatly 
                                        
                # Look through timeseries and if the overall supply is greater than the demand, 
                # curtail on generator
                # the variable generator that is used right now for the non-dispachtables,
                # returns variable costs of zero. Therefore we don't have to bother to substract
                # the curtailed supply from the costs, but in  future versions, this must be 
                # implemented.
                for t in range(self.data.ts_length):
                    sum_tx_supply = sum(tx_supply,1)
                    while sum_tx_supply[t] > abs(orig_supply[t]):
                        diff = sum_tx_supply[t] - abs(orig_supply[t])
                        # curtail
                        # pick generator, right now: stupidly pick biggest supplier out of generators and sites,
                        # better to use some information of where congestion was
                        max_supply = 0
                        for gen_type in self.pre_transmission_dispatch:
                            for idx, site in enumerate(period_results['generators'][gen_type]['site_indices']):
                                if period_results['generators'][gen_type]['supply'][idx][t] > max_supply:
                                    max_gen_type = gen_type
                                    max_idx = idx
                                    max_site = site
                                    max_supply = period_results['generators'][gen_type]['supply'][idx][t]
                                    
                        # curtail--
                        # substact from period_results
                        if diff < period_results['generators'][max_gen_type]['supply'][max_idx][t]:
                            period_results['generators'][max_gen_type]['supply'][max_idx][t] -= diff
                            sum_tx_supply[t] -= diff
                            tx_supply[max_site][t] -= diff
                            supply_request[t] += diff
                        else: 
                            sum_tx_supply[t] -= period_results['generators'][max_gen_type]['supply'][max_idx][t]
                            tx_supply[max_site][t] -= period_results['generators'][max_gen_type]['supply'][max_idx][t]
                            supply_request[t] += period_results['generators'][max_gen_type]['supply'][max_idx][t]
                            period_results['generators'][max_gen_type]['supply'][max_idx][t] = 0
                        
                        # adjust costs, not necessary right now since non-dispatchables have var. costs of zero
                           
                    t += 1
                    
             
                # Demand right now is distributed according to demand_map in data file.
                # This will need to be implemented into a demand model.
                for site, demand_ratio in self.data.demand_map:
                    tx_supply[site] += -1 * demand_ratio *  tx_supply_request
            
                tx_cost = 0

                tx_cost = self.transmission.calculate_cost(tx_state_handle, tx_supply )
                period_cost += tx_cost
                period_results['totals']['tx_cost'] = tx_cost  
                
#                print 'time used by tx:', time.time()-start_tx


            # Now supply the rest of the demand with the dispatchable energy ressources
            #   do not bother about transmission constraints or location
            for gen_type in self.dispatch_order:
                if gen_type in self.pre_transmission_dispatch:
                    continue
                
                gen = self.gen_list[gen_type]
                gen_ptr = self.gen_params[gen_type]

                gen_cost = 0        #cost for this generator in this period
                gen_carbon = 0.0    #carbon for this generator in this period
                
                #Calculate period
                period_results['generators'][gen_type] = gen.calculate_time_period_full( 
                        gen_state_handles[gen_type], period, params[gen_ptr[0]:gen_ptr[1]], 
                        supply_request, make_string=True, do_decommissioning = False)
                        
                #substract from supply_request
                supply_request -= numpy.sum(period_results['generators'][gen_type]['supply'], 0)

                # Add up costs and carbon
                # New capacity costs
                gen_cap_cost = 0
                for idx, value in enumerate(period_results['generators'][gen_type]['new_capacity']):
                    gen_cap_cost += value[2]
                gen_cost += gen_cap_cost
                # Variable costs
                gen_cost +=  numpy.sum(period_results['generators'][gen_type]['variable_cost_ts'])
                gen_carbon += numpy.sum(period_results['generators'][gen_type]['carbon_emissions_ts'])
                # Carbon costs
                if gen_carbon > 0:
                    gen_cost += gen_carbon * gen.config['carbon_price_m'][period]
                
                period_cost += gen_cost   
                period_carbon += gen_carbon   
                
                # add cost and total supply of generator into period_results
                period_results['generators'][gen_type]['new_capacity_cost'] = gen_cap_cost
                period_results['generators'][gen_type]['cost'] = gen_cost
                period_results['generators'][gen_type]['carbon'] = gen_carbon
                period_results['generators'][gen_type]['total_supply_period'] = numpy.sum(period_results['generators'][gen_type]['supply'])
            
            # End of period, save period_results in results  and 
            # add carbon and costs of period on totals
            total_carbon += period_carbon
            cost += period_cost
            
            period_results['totals']['cost'] = period_cost
            period_results['totals']['carbon'] = period_carbon
            
            results['periods'][period] = period_results
            
            
        # calculate the terminal value at the end of the last period
        total_terminal_value = 0.0
        

        final_period = self.run_periods[-1]
        for gen_type in self.dispatch_order:
            gen = self.gen_list[gen_type]
            terminal_value, site_terminal_value = gen.get_terminal_value(final_period, 
                gen_state_handles[gen_type])

            results['terminal']['generators'][gen_type] = {'total_value': terminal_value, 
                    'site_value': site_terminal_value}
            total_terminal_value += terminal_value
            
        cost -= total_terminal_value

        results['totals']['cost'] = cost
        results['totals']['carbon'] = total_carbon
        results['totals']['terminal_value'] = total_terminal_value

#        print 'total time used:', time.time()-start


        return cost, results



    def evaluate_results(self, params):
        """Collect a dict that includes all the calculated results from a
        run with params.
        
        Inputs:
            params: list of numbers, typically the best output from a run.
            
        Outputs:
            results: a dict of gen_type: gen_results
            where gen_results is the output from calculate_time_period_simple in
            txmultigenerator.py (or subclass), with full_results = True.
        """
        cost, results = self.calc_cost(params)
        return results
        
        
    def gene_test(self, gene):
        """input: list
        output: float
        takes the gene.values, tests it and returns the genes score
        """
        score = -1 * self.calc_cost(gene)[0]
        return score
