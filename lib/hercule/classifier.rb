require_relative 'classifier_engines/lsvm'

module Hercule
  class Classifier
    extend Forwardable
    
    #----------------------------------------------------------------------------
    # Instance Methods
    #----------------------------------------------------------------------------
    def initialize( options = {} )
      # Set up the delegation target to be used by Forwardable
      @target = nil

      if options[:lsvm]
        # Use the LibSVM classifier engine
        @target = ClassifierEngines::LSVM.new( options )
      elsif options[:custom]
        # Use a custom classifier engine, any type of object can be
        # used so long as it responds to the delegated methods
        @target = options[:custom]
      end
    end

    # Be careful!
    def engine
      @target
    end

    #----------------------------------------------------------------------------
    # Delegated Methods
    #----------------------------------------------------------------------------
    def_delegators :@target, :train, :trained?, :classify,
                             :persist, :persist!, :load, :load!

    #
    # train -    Train the model associated with this classifier using the
    #            specified document domain data
    #
    # trained? - Returns true/false indicating whether the classifer
    #            has been trained
    #
    # classify - Classify the specified document instance and return
    #            the newly labeled document along with any
    #            confidence/probability data for the prediction in the
    #            form of a hash like:
    #
    #            { :label_1 => 0.4, :label_2 => 0.6 }
    #
    # persist -  Persist the classification engine in some way so that
    #            subsequent instances can be loaded without having to
    #            retrain
    #
    # persist! - Same as persist method, but raises exceptions on
    #            persist failure
    #
    # load -     Load the classification engine from its persisted
    #            state
    #
    # load! -    Same as load method, but raises exceptions on load
    #            failure
    #

    # Below are the intended method signatures and return values, if any

    # def train( document_domain )
    #   raise ArgumentError unless document_domain.kind_of?( Hercule::Document::Domain )
    # end

    # def classify( document )
    #   raise ArgumentError unless document_domain.kind_of?( Hercule::Document )

    #   return [document, probability_values]
    # end
    
    # def persist( options )
    #   file_name = options[:file_name], ..., etc
    # end

    # def load( options )
    #   file_name = options[:file_name], ..., etc

    #   return successfully_loaded_boolean
    # end
  end
end
