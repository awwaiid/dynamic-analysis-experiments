
# If static analysis of a dynamic language is difficult,
# maybe we should do dynamic analysis instead.

require 'andand'
require 'set'
#  require 'pry-byebug'

class DynamicAnalysis

  # Generally the type is the class.
  # But for a few cases it is nice to peek a bit deeper.
  def typeof(n)
    if n.class == Array  
      "Array[#{n.first.andand.class}]"    
    elsif n.class == Hash  
      "Hash[#{typeof(n.first.andand.first)} => #{typeof(n.first.andand.last)}]"
    else  
      n.class.to_s
    end  
  end  

  def initialize(result_filename = "dynamic_analsysis.log")
    @types = {}
    @ids   = {}
    @deps  = {}
    @outfile = File.new(result_filename, 'w')
  end

  def log(entry)
    @outfile.puts entry
    #  @outfile.flush
  end

  def track_var(var, var_name, var_path, var_class)
    var_loc = "#{var_path} #{var_name}"
    var_id = var.object_id
    var_type = typeof(var)

    log "  Visible var #{var_loc} (#{var_id}): #{var_type}"

    old_type = @types[var_loc]
    if old_type && old_type != var_type && old_type != "NilClass"
      log "    TYPE CHANGE! #{var_loc} #{old_type} -> #{var_type}"
    end

    old_id = @ids[var_loc]
    if old_id && old_id != var_id
      #  log "    id CHANGE! #{var_loc} #{old_id} -> #{var_id}"
    end

    @types[var_loc] = var_type
    @ids[var_loc] = var_id

    # This also counts as a dependency
    @deps[var_class] ||= Set.new
    if ! @deps[var_class].include?(var_type) && var_class != var_type
      @deps[var_class].add(var_type)
      log "  ADDING DEP for #{var_class}: #{var_type}"
      log "  DEPS #{var_class}: #{@deps[var_class].to_a}"
    end
  end

  def start_trace
    set_trace_func proc { |event, file, line, id, line_binding, classname|
      next unless line_binding
      log(sprintf "TRACE: %8s %s:%-2d %10s %8s\n", event, file, line, id, classname)
      log(" SKIP") unless file.to_s =~ /railsgirls/
      next unless file.to_s =~ /railsgirls/
      
      var_method = line_binding.eval("__method__")
      var_class = line_binding.eval("self.class")
      if var_class == Class || var_class == Module
        var_class = line_binding.eval("self.to_s")
      end

      # General dependencies
      if classname && var_class.to_s != classname.to_s
        @deps[var_class] ||= Set.new
        if ! @deps[var_class].include?(classname.to_s)
          @deps[var_class].add(classname.to_s)
          log "  ADDING DEP for #{var_class}: #{classname}"
          log "  DEPS #{var_class}: #{@deps[var_class].to_a}"
        end
      end

      # Local variables
      line_binding.local_variables.each do |var_name|
        #  log "Var name: '#{var_name}'"
        # I have no idea what this is, but rails crashed without skipping it
        next if var_name =~ /#\$!/

        var = line_binding.local_variable_get(var_name)
        var_path = "#{var_class}##{var_method} #{var_path}"
        track_var(var, var_name, var_path, var_class)

      end

      # Instance variables
      line_binding.eval("self.instance_variables").each do |var_name|
        var = line_binding.eval("self.instance_variable_get(:#{var_name})")
        var_path = var_class
        track_var(var, var_name, var_path, var_class)
      end

      # Ideas:
      # * method types -- parameters & return value
    }
  end

  def stop_trace
    set_trace_func nil
  end

  def deps_to_dot(filename)
    File.open(filename, "w") do |dot|
      dot.puts "digraph {"
      @deps.each do |klass, deps|
        deps.each do |other_klass|
          dot.puts "  \"#{klass}\" -> \"#{other_klass}\";"
        end
      end
      dot.puts "}"
    end
  end

end
