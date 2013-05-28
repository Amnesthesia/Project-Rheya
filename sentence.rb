require "treat"
include Treat::Core::DSL

class Sentence
  attr_accessor :who, :to_whom, :is_question, :is_exclamation, :mood, :target, :nouns, :verbs, :adjectives, :adverbs, :words
  
  def initialize(*args)
    @sentence = args[1]
    @nouns = []
    @adjectives = []
    @words = []
    @verbs = []
    @adverbs = []
    @to_whom = []
    
    analyze(@sentence)
  end
  
  def analyze(msg)
    t = msg.to_entity.do(:chunk,:segment, :tokenize, :category)

    t.each_word do |m|
      unless m.to_s == nil
        @words << m.to_s
        if m.category == "noun"
          @nouns << [m.to_s.singular,t.frequency_of(m.to_s)] unless @nouns.include? m
        elsif m.category == "verb" and !@verbs.include? m.to_s.stem
          @verbs << m.to_s.stem
        elsif m.category == "adjective" and !@adjectives.include? m.to_s
          @adjectives << m.to_s
        elsif m.category == "adverb" and !@adverbs.include? m.to_s
          @adverbs << m.to_s
        elsif m.category == "interrogation"
          @is_question = true
        elsif m.category == "exclamation"
          @is_exclamation = true
        elsif m.to_s != "I" and m.category == "pronoun"
          @to_whom << m.to_s
        elsif m.to_s == "I" and m.category == "pronoun"
          @who = "source"
        end
      end
    end
  end
  
  
  
end