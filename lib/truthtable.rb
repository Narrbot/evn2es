# truthtable.rb - truth table and formula generator
#
# Copyright (C) 2007 Tanaka Akira  <akr@fsij.org>
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.

require 'truthtable/qm'

# = truth table and formula generator from Ruby block
#
# The truthtable library generates a truth table from
# a logical formula written in Ruby.
# The truth table can be converted to a logical formula.
#
# == Author
#
# Tanaka Akira <akr@fsij.org>
#
# == Feature
#
# * generate a truth table from a given block which contains logical formula written in Ruby.
# * generate a formula from the table:
#   * minimal one (obtained by Quine-McCluskey algorithm)
#   * disjunctive normal form
#   * conjunctive normal form
#
# == Usage
#
# * require
#
#    require 'truthtable'
#
# * puts, p and pp shows truth table
#
#    puts TruthTable.new {|v| v[0] & v[1] }
#    #=>
#    v[0] v[1] | 
#    ----------+--
#     f    f   | f
#     f    t   | f
#     t    f   | f
#     t    t   | t
#
#    p TruthTable.new {|v| v[0] & v[1] }
#    #=> #<TruthTable: !v[0]&!v[1]=>false !v[0]&v[1]=>false v[0]&!v[1]=>false v[0]&v[1]=>true>
#
#    require 'pp'
#    pp TruthTable.new {|v| v[0] & v[1] }
#    #=>
#    #<TruthTable:
#     !v[0]&!v[1]=>false
#     !v[0]& v[1]=>false
#      v[0]&!v[1]=>false
#      v[0]& v[1]=>true>
#
# * formula generation
#
#    p TruthTable.new {|v| v[0] }.formula         #=>"v[0]"
#    p TruthTable.new {|v| !v[0] }.formula        #=> "!v[0]"
#    p TruthTable.new {|v| true ^ v[0] }.formula  #=> "!v[0]"
#    p TruthTable.new {|v| v[0] & v[1] }.formula  #=> "v[0]&v[1]"
#    p TruthTable.new {|v| v[0] | v[1] }.formula  #=> "v[0] | v[1]"
#    p TruthTable.new {|v| v[0] ^ v[1] }.formula  #=> "!v[0]&v[1] | v[0]&!v[1]"
#    p TruthTable.new {|v| v[0] == v[1] }.formula #=> "!v[0]&!v[1] | v[0]&v[1]"
#
# * shortcuts, && and ||, are also usable but converted to & and |
#
#    p TruthTable.new {|v| v[0] && v[1] }.formula #=> "v[0]&v[1]"
#    p TruthTable.new {|v| v[0] || v[1] }.formula #=> "v[0] | v[1]"
#
# * actually any expression (without side effect)
#
#    p TruthTable.new {|v| v[0] ? !v[1] : v[1] }.formula #=> "!v[0]&v[1] | v[0]&!v[1]"
#
# * any number of inputs
#
#    p TruthTable.new {|v| [v[0], v[1], v[2], v[3]].grep(true).length <= 3 }.formula
#    #=> "!v[0] | !v[1] | !v[2] | !v[3]"
#
class TruthTable
  attr_accessor :table
  # :stopdoc:
  class TruthTableObject
    def initialize
      @checked = {}
      @plan = {}
      @order = []
      @queue = []
    end

    attr_reader :plan, :order

    def next_plan
      @log = {}
      @plan, @order = @queue.shift
      @plan
    end

    def method_missing(m, *args, &block)
      self.idx(m.to_s)
    end

    def [](var)
      self.idx(var)
    end

    def idx(var)
      s = var
      if @plan.has_key?(s)
        v = @plan[s]
      else
        fplan = @plan.dup
        fplan[s] = false
        fkey = fplan.keys.sort.map {|k| "#{k}=#{fplan[k]}"}.join(' ')
        @order += [s]
        @plan = fplan
        v = false
        if !@checked[fkey]
          tplan = @plan.dup
          tplan[s] = true
          tkey = tplan.keys.sort.map {|k| "#{k}=#{tplan[k]}"}.join(' ')
          torder = @order.dup
          torder[-1] = s
          @queue.unshift [tplan, torder]
          @checked[tkey] = true
          @checked[fkey] = true
        end
      end
      v
    end
  end
  # :startdoc:

  def self.test(&b)
    r = []
    o = TruthTableObject.new
    begin
      result = !!o.instance_eval(&b)
      inputs = o.plan
      order = o.order
      r << [inputs, result, order]
    end while o.next_plan
    r
  end

  # resolve one of variable
  def resolve(var, value)
    @table.delete_if {|t| t.first[var] != nil and t.first[var] != value}
  end

  def initialize(&b)
    table = TruthTable.test(&b)
    @table = table
  end

  def to_s
    r = ''
    names = sort_names(all_names.keys)
    format = ''
    sep = ''
    names.each {|name|
      format << "%-#{name.length}s "
      sep << '-' * (name.length + 1)
    }
    format << "| %s\n"
    sep << "+--\n"
    r << sprintf(format, *(names + ['']))
    r << sep
    @table.each {|inputs, output, order|
      h = {}
      each_input(inputs) {|name, input|
        h[name] = input
      }
      args = []
      names.each {|name|
        if h.has_key? name
          args << (h[name] ? 't' : 'f').center(name.length)
        else
          args << '?'.center(name.length)
        end
      }
      args << (output ? 't' : 'f')
      r << sprintf(format, *args)
    }
    r
  end

  # :stopdoc:
  def inspect
    result = "#<#{self.class}:"
    @table.each {|inputs, output, order|
      term = []
      each_input(inputs) {|name, input|
        if input
          term << name
        else
          term << "!#{name}"
        end
      }
      result << " #{term.join('&')}=>#{output}"
    }
    result << ">"
    result
  end

  def pretty_print(q)
    q.object_group(self) {
      q.text ':'
      q.breakable
      q.seplist(@table, lambda {q.breakable('; ')}) {|inputs, output, order|
        term = []
        each_input(inputs) {|name, input|
          if input
            term << " #{name}"
          else
            term << "!#{name}"
          end
        }
        q.text "#{term.join('&')}=>#{output}"
      }
    }
  end

  def all_names
    return @all_names if defined? @all_names
    @all_names = {}
    @table.each {|inputs, output, order|
      order.each {|name|
        if !@all_names.has_key?(name)
          @all_names[name] = @all_names.size
        end
      }
    }
    @all_names
  end

  def sort_names(names)
    total_order = all_names
    names.sort_by {|n| total_order[n]}
  end

  def each_input(inputs)
    sort_names(inputs.keys).each {|name|
      yield name, inputs[name]
    }
  end

  # :startdoc:

  # obtains a formula in disjunctive normal form.
  def dnf
    r = []
    @table.each {|inputs, output|
      return output.to_s if inputs.empty?
      next if !output
      term = []
      each_input(inputs) {|name, input|
        if input
          term << name
        else
          term << "!#{name}"
        end
      }
      r << term.join(' & ')
    }
    return "false" if r.empty?
    r.join(' | ')
  end

  # obtains a formula in conjunctive normal form.
  def cnf
    r = []
    @table.each {|inputs, output|
      return output.to_s if inputs.empty?
      next if output
      term = []
      each_input(inputs) {|name, input|
        if input
          term << "!#{name}"
        else
          term << name
        end
      }
      if term.length == 1
        r << term.join(' | ')
      else
        r << "(#{term.join(' | ')})"
      end
    }
    return "true" if r.empty?
    r.join(' & ')
  end

  # obtains a minimal formula using Quine-McCluskey algorithm.
  def formula
    input_names = all_names
    input_names_ary = sort_names(input_names.keys)
    tbl = {}
    @table.each {|inputs, output|
      return output.to_s if inputs.empty?
      inputs2 = [:x] * input_names.length
      inputs.each {|name, input|
        inputs2[input_names[name]] = input ? 1 : 0
      }
      tbl[inputs2] = output ? 1 : 0
    }
    qm = QM.qm(tbl)
    r = []
    qm.each {|term|
      t = []
      num_dontcare = 0
      term.each_with_index {|v, i|
        if v == false
          t << ("!" + input_names_ary[i])
        elsif v == true
          t << input_names_ary[i]
        else # :x
          num_dontcare += 1
        end
      }
      if num_dontcare == term.length
        r << 'true'
      else
        r << t.join(' & ')
      end
    }
    return "false" if r.empty?
    if r.length > 1
      r.map {|t| t.include?("&") ? "(#{t})" : t}.join(' | ')
    else
      r.first
    end

  end
end

if __FILE__ == $0
  p TruthTable.new {|v| v[0] & v[1]}.formula
  p TruthTable.new {|v| v[0] && v[1]}.formula
  p TruthTable.new {|v| v[0] | v[1]}.formula
  p TruthTable.new {|v| v[0] || v[1]}.formula
  p TruthTable.new {|v| v[0] ^ !v[1]}.formula
  p TruthTable.new {|v| v[0] == v[1]}.formula
  p TruthTable.new {|v| v[0] == v[1] && v[1] != v[2] || v[3] == v[1]}.formula
end

