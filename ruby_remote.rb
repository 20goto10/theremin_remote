require 'device_input'
require 'manticore'
require 'json'

config_file = File.read('config.json')
CONFIGURATION = JSON.parse(config_file)
BRIGHTNESS_SYNC_PERIOD = 20
MAX_CONCURRENT_REQUESTS = 8
REPEAT_DELAY = 20
DEBUG = !!CONFIGURATION['debug']

# use two clients because the MOUSE client should wipe out any existing connections each time it sends
CLIENTS = {
  'keyboard' => Manticore::Client.new,
  'mouse' => Manticore::Client.new
}
# (request_timeout: 2, connect_timeout: 2, socket_timeout: 8, pool_max: 12, pool_max_per_route: 1)

@px = 0.0
@py = 0.0
@brightness ||= {} 
@color ||= {} 

def mapped_keys
  @mapped_keys ||= CONFIGURATION['keyboard_bindings'].flat_map { |mapping| mapping['key'] }
end

def get_state
  result = CLIENTS['keyboard'].get("#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights").call
  JSON.parse(result.body).each do |k,v|
    @color[k.to_i] = v['state']['xy']
    @brightness[k.to_i] = v['state']['bri']
  end
end

def make_dimmer_call(light, intensity)
  ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'bri': intensity }.to_json }]
end

def make_color_call(light, values)
  ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'xy': values }.to_json }]
end

def make_power_call(light, on_state)
  @brightness[light] = 0 if !on_state
  ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'on': on_state }.to_json }]
end

def parallel_calls(datas, client_key)
  if client_key == 'mouse'
    CLIENTS[client_key].clear_pending
  end
  datas.each do |data|
    response = CLIENTS[client_key].background.parallel.put(*data)
    response.on_success do |response|
      puts "SUCCESS: #{response}" if DEBUG 
    end.on_failure do |response|
      puts "FAILED: #{response}" if DEBUG 
    end
  end
  CLIENTS[client_key].execute! 
rescue => e
  puts e.message if DEBUG
end

def perform_action_for(key, code = 0)
  bindings = CONFIGURATION['keyboard_bindings'].select { |item| item['key'] == key || (item['key'].is_a?(Array) && item['key'].include?(key)) }
  keyboard_actions = []
  bindings.each do |binding|
    if code == 0 # binding['repeatable'] # TODO: repeating requires awareness of when the key goes down and when up
      if binding['type'] == 'ha-bridge' 
        if binding['action'] == 'on' || binding['action'] == 'off' 
          keyboard_actions = binding['lights'].collect { |light| make_power_call(light, binding['action'] == 'on') } 
        elsif binding['action'] == 'dim'
          get_state
          keyboard_actions = binding['lights'].collect do |light| 
            @brightness[light] += binding['value']
            @brightness[light] = min_max(@brightness[light], 0, 254)
            make_dimmer_call(light, @brightness[light])
          end 
        elsif binding['action'] == 'random'
          keyboard_actions = binding['lights'].collect { |light| make_color_call(light, [rand(), rand()]) }
        elsif binding['action'] == 'rotate'
          target_lights = (binding['reversed'] ? binding['lights'].reverse : binding['lights'])
          get_state  
          color = @color[target_lights.last] 
          keyboard_actions = target_lights.collect do |light| 
            new_color_xy = color
            color = @color[light]
	    puts "#{light}: #{new_color_xy} / old color #{color}"
	    @color[light] = new_color_xy
            make_color_call(light, new_color_xy)
          end
        end
      end
    end
  end
  keyboard_actions
end

def min_max(val,min,max) 
  a = val < min ? min : val
  a > max ? max : a
end

def mouse_input_monitor
  File.open(CONFIGURATION['mouse_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      puts "Moved by #{event.data.value.to_f}" if (event.code == "X" || event.code == "Y") if DEBUG 
      if (['X','Y'].include?(event.code))
        get_state

        calls = CONFIGURATION['mouse_binding']['lights'].collect do |light| 
	  new_x = new_y = 0
          if (event.code == "X")
            new_x = @color[light][0] + (event.data.value.to_f / CONFIGURATION['max_x_resolution'])
	    new_y = @color[light][1]
          end
          if (event.code == "Y")
	    new_x = @color[light][0]
            new_y = @color[light][1] - (event.data.value.to_f / CONFIGURATION['max_y_resolution']) # the operator is a - because Y is inverted (0,0 is the top left corner)
          end
	  if CONFIGURATION['drift']
	    new_x += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
	    new_y += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
          end 
          new_xy = [min_max(new_x,0,1.0),min_max(new_y,0,1.0)] 
	  @color[light] = new_xy 
          make_color_call(light, new_xy)
        end
        parallel_calls(calls, 'mouse')
      end
    end
  end
end

def keyboard_input_monitor
  File.open(CONFIGURATION['keyboard_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      if event.type == 'EV_KEY' 
        if mapped_keys.include?(event.code)  
          parallel_calls(perform_action_for(event.code, event.data.value), 'keyboard')
        else
          puts "#{event.code} is not a mapped key" if DEBUG
        end
      end
    end
  end
end

get_state
pp @brightness if DEBUG
puts "Bound keys: #{mapped_keys.join(",")}" if DEBUG
t3 = Thread.new do 
  loop do
    begin
      mouse_input_monitor
    rescue => e
      pp e
    end
  end
end unless CONFIGURATION['mouse_disabled']
t4 = Thread.new do 
  loop do
    begin
      keyboard_input_monitor
    rescue => e
      pp e
    end
  end
end unless CONFIGURATION['keyboard_disabled']
t3.join unless CONFIGURATION['mouse_disabled']
t4.join unless CONFIGURATION['keyboard_disabled']
