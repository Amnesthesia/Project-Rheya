require "treat"
require "./sentence.rb"

class Brain
  
  def initialize(*args)
  end
  
  
  def get_topic(msg)
    score = 0
    
    nouns = get_nouns(msg)

    # Sort nouns by value (which is their occurance)
    nouns.sort_by{|k,v| v}.reverse
    
    
    topic = []
    i = 0
    
    nouns.each do |n|
      topic << n[0].to_s
      if i > (nouns.count / 2).round
        break
      end  
    end
    
    return topic
  end
  
  def get_nouns(msg)
    s = Sentence.new(:export_name,msg)
    
    nouns = {}
   
    s.nouns.each do |m|
      nouns[m[0].to_sym] = m[1]
    end
    return nouns
  end
  
  def get_adjectives
  end
  
  
end