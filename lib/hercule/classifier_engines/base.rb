require 'svm'

module Hercule
  module ClassifierEngines
    class Base
      #----------------------------------------------------------------------------
      # Instance Methods
      #----------------------------------------------------------------------------
      def initialize( options = {} )
        @trained_document_domain = nil
        @trained = false
      end

      def train( document_domain )
        # Stash the document domain for future reference
        @trained_document_domain = document_domain
      end

      def trained?
        @trained
      end

      def classify( document )
        raise 'Virtual method on base class, must be defined on subclass'
      end
    end
  end
end
