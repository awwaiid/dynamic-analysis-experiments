#!/usr/bin/env ruby

require_relative 'dynamic-analysis'

da = DynamicAnalysis.new('analysis.log')
da.start_trace

x = 5
y = [20]
z = { a: x }

lala = { a: z }

module La
  module Tee
    class Da
      def hmm(n)
        @foo = 7
        puts "howdy, #{n}"
        n = 23
        3.times do |i|
          # 'i' can only be seen from in here
          puts i
        end
        @foo = "hmm"
        puts "Hmm... #{n}"
      end
    end
  end
end

La::Tee::Da.new.hmm("steve")

puts "hiya"

x = "boo!"
x = "fish!"

da.stop_trace
da.deps_to_dot("out.dot")

