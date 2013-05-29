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
    i = 1
    
    nouns.each do |n|
      topic << n[0].to_s.downcase
      if (nouns.count>3) and i > (nouns.count / 2).round
        break
      end  
      i += 1
    end
    
    return topic
  end
  
  def get_nouns(msg)
    s = Sentence.new(:export_name,msg)
    s.analyze(msg)
    
    nouns = {}
   
    unless s.nouns.empty?
      s.nouns.each do |m|
        nouns[m[0].to_sym] = m[1]
      end
    end
    return nouns
  end
  
  def get_adjectives
    
  end
  
  
end