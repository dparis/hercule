require 'spec_helper'

describe Hercule::Preprocessor do
  before(:each) do
    @text = "This is a bit of sample text. It has some punctuation.
             It also as some numerals, like 12345, and symbols! Here's both: $123.45"

    @text_tokenized_and_downcased = ["this", "bit", "sample", "text", "has", "some",
                                     "punctuation", "also", "some", "numerals", "like",
                                     "12345", "and", "symbols", "here's", "both",
                                     "$123.45"]

    @text_stripped_symbols = ["this", "bit", "sample", "text", "has", "some", "punctuation",
                              "also", "some", "numerals", "like", "12345", "and", "symbols",
                              "heres", "both", "12345"]

    @text_stripped_numerals = ["this", "bit", "sample", "text", "has", "some", "punctuation",
                               "also", "some", "numerals", "like", "and", "symbols",
                               "here's", "both"]

    @text_stripped_stop_words = ["bit", "sample", "text", "punctuation", "numerals",
                                 "12345", "symbols", "here's", "both", "$123.45"]

    @text_stemmed_words = ["thi", "bit", "sampl", "text", "some", "punctuat", "also",
                           "some", "numer", "like", "12345", "and", "symbol", "here'",
                           "both", "$123.45"]

    @short_text = "THIS IS A SHORTER TEST STRING $1234"
    @short_text_tokenized = ["THIS", "IS", "A", "SHORTER", "TEST", "STRING", "$1234"]

    @word = "Testing"
    @word_stem = "Test"
    
    @preproc = Hercule::Preprocessor.new
  end

  context 'class constants' do
    it 'should define default stop words' do
      Hercule::Preprocessor.const_defined?( :DEFAULT_STOP_WORDS ).should be_true
    end
  end

  context 'class methods' do
    it 'should tokenize a string' do
      Hercule::Preprocessor.tokenize( @short_text ).should == @short_text_tokenized
    end
    
    it 'should stem a word' do
      Hercule::Preprocessor.stem( @word ).should == @word_stem
    end
  end

  context 'attributes' do
    it 'should provide access to the minimum token length' do
      @preproc.min_token_length = 5
      @preproc.min_token_length.should == 5
    end

    it 'should provide access to the stop word list' do
      @preproc.stop_words = ['new', 'stop', 'words']
      @preproc.stop_words.should == ['new', 'stop', 'words']
    end

    it 'should allow stripping symbols to be toggled' do
      @preproc.strip_symbols = false
      @preproc.strip_symbols.should be_false
    end
    
    it 'should allow stripping numerals to be toggled' do
      @preproc.strip_numerals = false
      @preproc.strip_numerals.should be_false
    end

    it 'should allow stemming words to be toggled' do
      @preproc.stem_words = false
      @preproc.stem_words.should be_false
    end

    it 'should allow stripping stop words to be toggled' do
      @preproc.strip_stop_words = false
      @preproc.strip_stop_words.should be_false
    end
  end

  context 'initialization' do
    context 'default values' do
      it 'should be be 3 for minimum token length' do
        @preproc.min_token_length.should == 3
      end

      it 'should toggle word stemming on' do
        @preproc.stem_words.should be_true
      end

      it 'should toggle stripping symbols' do
        @preproc.strip_symbols.should be_true
      end

      it 'should toggle stripping numerals' do
        @preproc.strip_numerals.should be_true
      end

      it 'should toggle stripping stop words' do
        @preproc.strip_stop_words.should be_true
      end

      it 'should define the stop word list as the list defined by the DEFAULT_STOP_WORDS constant' do
        @preproc.stop_words.should == Hercule::Preprocessor::DEFAULT_STOP_WORDS
      end
    end

    context 'options' do
      it 'should set the minimum token length' do
        new_preproc = Hercule::Preprocessor.new( :min_token_length => 7 )
        new_preproc.min_token_length.should == 7
      end

      it 'should indicate whether to stem words' do
        new_preproc = Hercule::Preprocessor.new( :stem_words => false )
        new_preproc.stem_words.should be_false
      end

      it 'should indicate whether to strip symbols' do
        new_preproc = Hercule::Preprocessor.new( :strip_symbols => false )
        new_preproc.strip_symbols.should be_false
      end

      it 'should indicate whether to strip numerals' do
        new_preproc = Hercule::Preprocessor.new( :strip_numerals => false )
        new_preproc.strip_numerals.should be_false
      end
      
      it 'should indicate whether to strip stop words' do
        new_preproc = Hercule::Preprocessor.new( :strip_stop_words => false )
        new_preproc.strip_stop_words.should be_false
      end

      it 'should set the stop word list' do
        new_preproc = Hercule::Preprocessor.new( :stop_words => ['new', 'stop', 'words'] )
        new_preproc.stop_words.should == ['new', 'stop', 'words']
      end
    end
  end

  context 'instance methods' do
    context 'preprocess method' do
      before(:each) do
        @pp_min_options = Hercule::Preprocessor.new( :stem_words => false,
                                                     :strip_symbols => false,
                                                     :strip_numerals => false,
                                                     :strip_stop_words => false )
      end
      
      it 'should tokenize and downcase the text' do
        tokenized_and_downcased = @pp_min_options.preprocess( @text )
        tokenized_and_downcased.should == @text_tokenized_and_downcased
      end
      
      it 'should optionally strip symbols' do
        @pp_min_options.strip_symbols = true
        text_stripped_symbols = @pp_min_options.preprocess( @text )
        text_stripped_symbols.should == @text_stripped_symbols
      end

      it 'should optionally strip numerals' do
        @pp_min_options.strip_numerals = true
        text_stripped_numerals = @pp_min_options.preprocess( @text )
        text_stripped_numerals.should == @text_stripped_numerals
      end

      it 'should optionally strip stop words' do
        @pp_min_options.strip_stop_words = true
        text_stripped_stop_words = @pp_min_options.preprocess( @text )
        text_stripped_stop_words.should == @text_stripped_stop_words
      end

      it 'should optionally stem words' do
        @pp_min_options.stem_words = true
        text_stemmed_words = @pp_min_options.preprocess( @text )
        text_stemmed_words.should == @text_stemmed_words
      end
    end
  end
end
