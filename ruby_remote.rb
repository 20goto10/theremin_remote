require 'device_input'
require 'rest-client'
require 'json'

config_file = File.read('config.json')
CONFIGURATION = JSON.parse(config_file)

@px = 0.0
@py = 0.0
@mouse_cmd_set = []
@keyboard_actions = []

def mapped_keys
  @mapped_keys ||= CONFIGURATION['keyboard_bindings'].flat_map { |mapping| mapping['key'] }
end

def make_color_call(light, values)
  call = ['put', "#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", {'xy': values}.to_json, {content_type: :json, accept: :json}]
end

def make_power_call(light, on_state)
  call = ['put', "#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", {'on': on_state}.to_json, {content_type: :json, accept: :json}]
end

def make_the_call(data)
  Thread.new { RestClient.send(data[0].to_sym, data[1], data[2], data[3]) }
end

def exec_mouse_queue
  loop do
    # replace this with direct curl commands and clean callbacks and rescues for when it fails...
    if @mouse_cmd_set.any?
      mouse_cmds = @mouse_cmd_set.last
      @mouse_cmd_set = []
      puts "Mouse command: #{mouse_cmds}"
      mouse_cmds.each { |mscmd| make_the_call(mscmd) }
    end 
  end
end

def exec_keyboard_queue
  loop do
    # replace this with direct curl commands and clean callbacks and rescues for when it fails...
    if @keyboard_actions.any?
      cmd = "./xy_color #{@xy_x} #{@xy_y}"
      kbd_cmd = @keyboard_actions.shift
      puts "Keyboard command: #{kbd_cmd}" 
      make_the_call(kbd_cmd)
    end 
  end
end

def perform_action_for(key)
  bindings = CONFIGURATION['keyboard_bindings'].select { |item| item['key'] == key || (item['key'].is_a?(Array) && item['key'].include?(key)) }
  bindings.each do |binding|
    if binding['type'] == 'ha-bridge' 
      binding['lights'].each do |light|
        @keyboard_actions << make_power_call(light, binding['action'] == 'on') 
      end
    end
  end
end

def mouse_input_monitor
  @xy_x = 0.0
  @xy_y = 0.0
  File.open(CONFIGURATION['mouse_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      puts "Moved by #{event.data.value.to_f}" if (event.code == "X" || event.code == "Y")
      if (['X','Y'].include?(event.code))
        if (event.code == "X")
          @px += event.data.value.to_f
          @px = CONFIGURATION['max_x_resolution'] if @px > CONFIGURATION['max_x_resolution']
          @px = 0.0 if @px < 0
          @xy_x = @px.to_f / CONFIGURATION['max_x_resolution']
        end
        if (event.code == "Y")
          @py += event.data.value.to_f
          @py = CONFIGURATION['max_y_resolution'] if @py > CONFIGURATION['max_y_resolution']
          @py = 0.0 if @py < 0
          @xy_y = @py.to_f / CONFIGURATION['max_y_resolution']
        end
	puts "#{@xy_x} #{@xy_y} // #{@px} #{@py}"
        @mouse_cmd_set << CONFIGURATION['mouse_binding']['lights'].collect { |light| make_color_call(light, [@xy_x,@xy_y]) }
      end
    end
  end
end

def keyboard_input_monitor
  File.open(CONFIGURATION['keyboard_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      if event.type == 'EV_KEY' && event.data.value == 0
        if mapped_keys.include?(event.code)  
          perform_action_for(event.code)
        else
          puts "#{event.code} is not a mapped key"
        end
      end
    end
  end
end

puts "Bound keys: #{mapped_keys.join(",")}"
t1 = Thread.new{exec_mouse_queue} unless CONFIGURATION['mouse_disabled']
t2 = Thread.new{exec_keyboard_queue} unless CONFIGURATION['keyboard_disabled']
t3 = Thread.new{mouse_input_monitor} unless CONFIGURATION['mouse_disabled']
t4 = Thread.new{keyboard_input_monitor} unless CONFIGURATION['keyboard_disabled']
t1.join unless CONFIGURATION['mouse_disabled']
t2.join unless CONFIGURATION['keyboard_disabled']
t3.join unless CONFIGURATION['mouse_disabled']
t4.join unless CONFIGURATION['keyboard_disabled']
