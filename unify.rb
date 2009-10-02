
# unifier in pure ruby

# "string ?x and ?y".unify "string joao and ?y" => hash[:x] = "joao" and hash[:y] = :y
# "string ?x and ?y".unify "string joao and ?y" => hash[:x] = "joao" and hash[:y] = :y

require 'breakpoint' 
module PrologUtils

SEPARATOR_VAR = /\?\w+/


def var?(var)
  if ( var.instance_of? String ) && ( ( var =~ SEPARATOR_VAR ) != nil)
    true
  else
    false
  end
end

def unify_var(var, elem, binds)
  if (binds.empty? || binds[var] == nil)
    binds[var] = elem
    return true
  elsif binds[var]
    if var? binds[var]
      binds[var] = elem
      return true
    else
      return false
    end
    
  end
  return false
end
   
# nao esta a funcionar
# "string o ?x foi a casa".unifier "string o ?x foi a ?x" 
def create_unify_func(hash, to_iter)
  lambda do |word , i|
    if var?(word) 
      unify_var(word,to_iter[i], hash)
    elsif ( word == to_iter[i] ) || (var? to_iter[i])
      next
    else
      hash[:invalid] = true
    end
    end
end
      
# "string foi ao ?x".unify "string foi ao ?x"
    
def unify(other)
  binds_self = Hash.new
  binds_other = Hash.new
  unifier_str_self = create_unify_func binds_self , other.split(" ")
  unifier_str_other = create_unify_func binds_other, self.split(" ")
  self.split(" ").each_with_index &unifier_str_self
  other.split(" ").each_with_index &unifier_str_other
  if (binds_self[:invalid] || binds_other[:invalid])
    return false
  end
  puts "Debug binds_self:" + binds_self.inspect
  puts "Debug binds_other:" + binds_other.inspect
  binds_self.merge_with_block(binds_other) do |val1,val2|
    var?(val1) ? val2 : val1
  end
end

def use_bindings(bindings)
  result = self.dup
  bindings.each {|key,value| result.gsub!(key,value)}
  result
end
def unifier(other)
  bindings = self.unify other
  return false unless bindings
  result = self.dup
  @debug_hash = bindings.dup
#  breakpoint
  bindings.each { |key,value| result.gsub!(key,value) }
  result
end
end

class String
  include PrologUtils
end

class Hash
  def merge_with_block(other, &b)
    result = self.dup
    other.each do |key,value|
      unless result[key]
        result[key] = value
      else
        result[key] = b.call(value,result[key])
      end
    end
    result
  end
end
=begin
hash1 = {:um => 1 , :dois => 2 , :tres => 3}
hash2 = {:quatro => 4, :cinco => 5, :seis => 6, :um => 10}
resultado = hash1.merge_with_block(hash2){ |val1,val2| val1 > val2 ? val2 : val1}
puts resultado.inspect
=end


require 'singleton'
class PrologDB
  include Singleton
  attr_accessor :predicates

  def initialize
    @predicates = Hash.new
  end

  def add(pred)
     if pred.instance_of? Predicate
       add_predicate pred
     elsif pred.instance_of? String # need to create a clause
       add_clause pred
     else
       raise "What Are you giving me?"
     end
  end

  def add_predicate(pred)
    @predicates[pred.name] = pred
  end
  
  def add_clause(clause)
    clause = Clause.new clause
    pred = clause.get_predicate
    if @predicates[pred]
      @predicates[pred].clauses << clause
    else
      puts "Debug: There's no predicate for that #{clause}"
      @predicates[pred] = Predicate.new clause.get_predicate
      @predicates[pred].clauses << clause
    end
  end

  def question(quest)
    #raise "Not implemented yet, PrologDB.question"
    arquest = quest.split(" ")
    pred = arquest[0]
    raise "#{pred} Doesn't exist in prolog database " unless @predicates[pred]
    return question_try(quest,@predicates[pred])
  end

  def question_try(ques,predicate)
    puts "trying #{predicate.name}"
    puts "num clause: #{predicate.clauses.size}"
    predicate.clauses.each do |clause|
      val = clause.head.unify ques
      puts "Clause #{clause.inspect}"
      puts "question #{ques}"
      puts "val: #{val.to_s}"
      #isto e um facto
      if val && clause.body.empty?
        puts "aahha descobri!!"
        return [true,val]
       #regra
      elsif val
        puts "unifica com: #{clause.head}"
        clause.body.each do |c| 
          predicate_name = c.get_predicate
          predicate_test = @predicates[predicate_name]
          nques = c.head.use_bindings(val)
          if predicate_test
            newval = question_try(nques,predicate_test)
            return [true,newval] if newval
          end
        end
      else
        next
      end
    end
    return false
  end
  
  alias << add
end
    


#Predicate ex: like
#clauses ex: likes joao joana
#clauses ex: likes ?X joana => animal x
class Predicate
  attr_accessor :clauses
  attr_reader :name

  def initialize(namep)
    self.clauses = Array.new
    @name = namep
    PrologDB.instance << self
  end

  def add_clause(clause)
    @clauses << Clause.new(clause)
  end

  alias << add_clause
end

class Clause
  attr_reader :head, :body

  def initialize(str)
    ar = str.split("=>")
    ar.each {|str| str.strip! }
    raise "Malformed clause: #{str}" if ar.size < 1
    @head = ar[0]
    @body = Array.new
    if ar.size > 1 # the clause has rules
      cbody = ar[1].split(",")
      cbody.each {|str| str.strip! }
      cbody.each do |cbodyuni|
        @body << Clause.new(cbodyuni)
      end
    end
  end
  

  def get_predicate
    strs = head.split(" ")
    return strs[0]
  end
end


#BUG!!!
# a virgula esta a funcionar como um "ou" e devia estar a funcionar como um "e"
# o problema esta no question_try , em vez do each tem de ser um collect
# o resultado tem de ser avaliado como um todo
PrologDB.instance << "likes joao joana"
PrologDB.instance << "likes ?x joao=> girl ?x"
PrologDB.instance << "university feup"
PrologDB.instance << "student ?x ?y => university ?y , smart ?x"
PrologDB.instance << "smart joao"
PrologDB.instance << "smart manuel"
PrologDB.instance << "girl joana"

breakpoint
=begin
Questoes tipicas
PrologDB.instance.question "likes teresa pedro" => false

PrologDB.instance.question "likes joao joana" => true

PrologDB.instance.question "likes joana joao" => true
=end
