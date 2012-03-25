module Hercule
  class BaseError < StandardError; end

  class ClassifierError < BaseError; end
  class DocumentError < BaseError; end
  class PreprocessorError < BaseError; end
end
