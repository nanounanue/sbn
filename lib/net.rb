class Sbn
  enums %w(INFERENCE_MODE_VARIABLE_ELIMINATION,
           INFERENCE_MODE_MARKOV_CHAIN_MONTE_CARLO)
  
  MCMC_NUM_SAMPLES = 2000
  
  class Net
    def initialize(name = '')
      @@net_count ||= 0
      @@net_count += 1
      @name = (name.empty? ? "net_#{@@net_count}" : name.underscore).to_sym
      @nodes = {}
      @evidence = {}
    end
    
    def add_node(node)
      @nodes[node.name] = node
    end
    
    def <<(obj)
      if obj.is_a? Array
        obj.each {|n| add_node(n) }
      else
        add_node(obj)
      end
    end
    
    def set_evidence(event)
      @evidence = event.symbolize_keys_and_values
    end

  	# Returns the estimated posterior probability for the specified node based
  	# on previously-supplied evidence, using the Markov Chain Monte Carlo
  	# algorithm.  The MCMC algorithm generates each event by making a random
  	# change to the preceding event.  The next state is generated by randomly
  	# sampling a value for one of the nonevidence variables Xi, conditioned on
  	# the current values of the variables in the Markov blanket of Xi.  MCMC
  	# basically wanders randomly around the state space--the space of possible
  	# complete assignments--flipping one variable at a time, but keeping the
  	# evidence variables fixed.  The sampling process works because it settles
  	# into a "dynamic equilibrium" in which the long-run fraction of time spent
  	# in each state is proportional to its posterior probability.
    def query_node(nodename)
      state_frequencies = {}
      e = generate_random_event
      relevant_e = relevant_evidence(nodename, e)
      MCMC_NUM_SAMPLES.times do
        state = e[nodename]
        state_frequencies[state] ||= 0
        state_frequencies[state] += 1
        
        relevant_e.each do |nname, nstate|
          # if this node is already set in the evidence or we've already
          # generated a random state for this node, skip over it
          e[nname] = @nodes[nname].get_random_state_with_markov_blanket(e)
        end
      end
      
      # normalize results
      magnitude = 0
      returnval = {}
      state_frequencies.each_value {|count| magnitude += count }
      state_frequencies.each {|state, count| returnval[state] = count / magnitude.to_f }
      returnval
    end
    
  private
    def relevant_evidence(nodename, evidence)
      returnval = {}
      evidence.each do |name, state|
        next if @evidence.has_key?(name)
        next unless @nodes[nodename].is_affected_by?(@nodes[name], evidence)
        returnval[name] = state
      end
      returnval
    end
  
    # Returns an event in which nodes that are not fixed by the evidence are set
    # to random states whose frequencies (after repeated calls) are consistent
    # with the network's joint probability distribution.
    def generate_random_event
      returnval = @evidence.dup
      @nodes.each do |name, node|
        next if @evidence.has_key?(name)
        returnval[name] = node.get_random_state(returnval) if node.can_be_evaluated?(returnval)
      end
      returnval
    end
  end
end
