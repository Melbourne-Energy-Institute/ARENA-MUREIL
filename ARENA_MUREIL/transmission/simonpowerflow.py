# -*- coding: utf-8 -*-
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
from tools import configurablebase
import numpy as np
import copy
import time


class SimonPowerFlow(configurablebase.ConfigurableMultiBase):
    """The power flow class, which can serve as a transmission model for
    an energy system model. In the current version it returns the amount
    of failed transmission.
    """

    def __init__(self):
        """Initiates a class member of the power flow class.
        """
        configurablebase.ConfigurableMultiBase.__init__(self)        
        
        self.state_handle = None
        self.startup_state = {}
        self.b_inverse_matrix = np.matrix(1)
        self.a_d_matrix = np.matrix(1)
        self.no_edges = 0
        self.total_unresolved_flow = 0
        self.line_dictionary = {}
        self.no_timeseries = 0
        self.y_bus = []
        self.a_matrix = []
        self.capacity_matrix = []



    def get_config_spec(self):
        """Return a list of tuples of format (name, conversion function, default),
        e.g. ('capex', float, 2.0). Put None if no conversion required, or if no
        default value, e.g. ('name', None, None)

        Configuration:
        """
        return [
            ('y_bus_name', None, None),
            ('a_matrix_name', None, None),
            ('capacity_matrix_name', None, None),
            ('penalty_failed_transmission', float, 10.0)
            ]


    def get_startup_state_handle(self):
        """Return a copy of the startup state, for use as the state_handle.
        """
        return copy.deepcopy(self.state_handle)

        
         
    def get_data_types(self):
        """Return a list of keys for each type of data required. 
        """
        
        return [self.config['y_bus_name'],
                self.config['a_matrix_name'],
                self.config['capacity_matrix_name']
                ] 

 
    def set_data(self, data):
        """Prepares the transmission network for the flow calculation. Sets
        up the matrixes needed for the flow calculation, namely b_inverse_matrix
        and the a_d_matrix. Further creates a line_dictionary with information
        about origin node, destination node, capacity and admittance value for
        each line. 
        
        N: number of nodes
        M: number of lines
        
        Input:
            data:
                containing:
                y_bus: (NxN) nodal attmittance matrix with 
                    y-bus(i,j) = -Y(i,j) for non-diagonal values and
                    y-bus(i,i) = Y(i,i) + sum(Y(i,j): for j:(1,N) & j != i) 
                    In this simple DC power flow model the resistance is 
                    neglected, therefore the admittance y = -j * b with b 
                    being the suspectance.
                    
                a_matrix: (MxN) node-arc incidence matrix, with 
                    a(m,n) = 1 if arc m has its starting point in node n
                    a(m,n) = -1 if arc m has its end point in node n#
                    a(m,n) = 0 otherwise
                    
                capacity_matrix: (NxN) matrix of the line capacities
                    capacity(i,j) = tranfer capacity between node i and node j
                    (note: capacity(i,j) can be different from capacity(j,i))
                    
        Output:
            none, but saves mentioned results in self. variables 
                    
        """
        self.y_bus = data[self.config['y_bus_name']]
        self.a_matrix = data[self.config['a_matrix_name']]
        self.capacity_matrix = data[self.config['capacity_matrix_name']]
        self.penalty_failed_transmission = self.config['penalty_failed_transmission']
        self.no_edges = len(self.a_matrix)
        
        # Calculate b_inverse_matrix
        # first calculate b_prime_matrix, which is the negative of the y-bus,
        # but the diagonal elements are replaced by the sum of the b-values
        # in the row of the respective element.
        # shape: (N-1) x (N-1)
        b_prime_matrix = -1 * self.y_bus[1:,1:] 
        for i, row in enumerate(b_prime_matrix):
            # replace diagonal elements with sum of all other elements of its row
            b_prime_matrix[i][i] = sum(self.y_bus[i+1]) - self.y_bus[i+1][i+1]
        self.b_inverse_matrix = np.linalg.inv(b_prime_matrix)        
        
        #Calculate D-matrix and capacity_vector and create line_dictionary
        d_matrix = np.zeros((self.no_edges,self.no_edges))
        i=0        
        while i < self.no_edges:
            row = list(self.a_matrix[i])
            orig_id = row.index(1)
            dest_id = row.index(-1)
            
            d_matrix[i][i] = self.y_bus[orig_id][dest_id]
            
            self.line_dictionary[i] = {'origin': orig_id, 'destination': dest_id,
                                    'capacity_in':self.capacity_matrix[orig_id][dest_id],
                                    'capacity_ag':self.capacity_matrix[dest_id][orig_id],
                                    'Y':self.y_bus[orig_id][dest_id] }   
            i=i+1
  
        # Calculate a_d_matrix
        # := transfer admittance matrix
        #  (M x N-1)
        #  with a_d(line i, node j) := -b(i) if j is end node of line
        #                               b(i) if j is start node of line
        self.a_d_matrix = np.matrix(d_matrix) * np.matrix(self.a_matrix)[:,1:]      
    

    def calculate_cost(self, tx_state_handle, supply):
        """Calculates the power flow for the current supply set, which is 
        provided by the txmultigenerator. The method 
        set_data needs to be run before calculating the
        flow.

        Inputs: 
            tx_state_handle: state_handle object for the transmission network, not used right now, but could be used if 
                network will be made changeable
            supply: a timeseries of supply vectors 
        Output:
            cost: a cost penalty for unresolved flow

        """
        # Loop through full timeperiod
        total_unresolved_flow = 0
        cost = 0        
        t = 0
        while t < len(supply[0]):    
                        
            supply_vector = np.matrix(np.array(supply.T[t])[1:])  

            # Calculate the nodal phase angles
            phase_angle_vector =  self.b_inverse_matrix * supply_vector.T
    
            # Calculate the line flows    
            flow_vector = self.a_d_matrix * phase_angle_vector
            
            # Considering capacities
            i = 0
            while i < self.no_edges:                
                if flow_vector.item(i) >= 0:
                    flow_difference = flow_vector.item(i) - \
                                    self.line_dictionary[i]['capacity_in']
                else:          
                    flow_difference = -flow_vector.item(i) - \
                                    self.line_dictionary[i]['capacity_ag']
                if flow_difference > 0:
                    total_unresolved_flow += flow_difference    
                i += 1
            t += 1    
        cost = total_unresolved_flow * self.penalty_failed_transmission
        
        return cost

