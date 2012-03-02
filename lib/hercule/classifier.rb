require 'svm'

module Hercule
  module Classifier
    class SVM
      #----------------------------------------------------------------------------
      # Attributes
      #----------------------------------------------------------------------------
      # NOTE:  SVM ATTRIBUTES ONLY FOR TESTING
      attr_reader :svm_model, :svm_problem, :svm_parameters
      attr_reader :labels

      #----------------------------------------------------------------------------
      # Instance Methods
      #----------------------------------------------------------------------------
      def initialize( options = {} )
        # Set up defaults
        @svm_parameters = Parameter.new

        # For documentation regarding what these parameters do, see the
        # following link: http://www.csie.ntu.edu.tw/~cjlin/libsvm/
        @svm_parameters.c          = options[:svm_c] || 10
        @svm_parameters.eps        = options[:svm_eps] || 0.001
        @svm_parameters.cache_size = options[:svm_cache_size] || 1 # In megabytes

        @svm_problem = Libsvm::Problem.new

        @labels = {}
      end

      def train( label, features )
        
      end
    end
  end
end
