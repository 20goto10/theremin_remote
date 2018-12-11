require 'device_input'
require 'manticore'
require 'json'

config_file = File.read('config.json')
CONFIGURATION = JSON.parse(config_file)
BRIGHTNESS_SYNC_PERIOD = 20
MAX_CONCURRENT_REQUESTS = 8
DEBUG = !!CONFIGURATION['debug']
@manticore_client = Manticore::Client.new(request_timeout: 2, connect_timeout: 2, socket_timeout: 5, pool_max: 10, pool_max_per_route: 2)

@px = 0.0
@py = 0.0
@brightness ||= {} 

def mapped_keys
  @mapped_keys ||= CONFIGURATION['keyboard_bindings'].flat_map { |mapping| mapping['key'] }
end

def get_brightness
  result = @manticore_client.get("#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights")
  JSON.parse(result.body).each do |k,v|
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

def parallel_calls(datas)
  datas.each do |data|
    response = @manticore_client.background.parallel.put(*data)
    response.on_success do |response|
      puts "SUCCESS: #{response}" if DEBUG 
    end.on_failure do |response|
      puts "FAILED: #{response}" if DEBUG 
    end
  end
  @manticore_client.execute! 
end

def perform_action_for(key)
  bindings = CONFIGURATION['keyboard_bindings'].select { |item| item['key'] == key || (item['key'].is_a?(Array) && item['key'].include?(key)) }
  keyboard_actions = []
  bindings.each do |binding|
    if binding['type'] == 'ha-bridge' 
      binding['lights'].each do |light|
        if binding['action'] == 'on' || binding['action'] == 'off' 
          keyboard_actions.push(make_power_call(light, binding['action'] == 'on'))
        elsif binding['action'] == 'dim'
          @brightness[light] += binding['value']
          @brightness[light] = 254 if @brightness[light] > 254
          @brightness[light] = 0 if @brightness[light] < 0
          keyboard_actions.push(make_dimmer_call(light, @brightness[light]))
        end 
      end
    end
  end
  keyboard_actions
end

def mouse_input_monitor
  @xy_x = 0.0
  @xy_y = 0.0
  File.open(CONFIGURATION['mouse_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      puts "Moved by #{event.data.value.to_f}" if (event.code == "X" || event.code == "Y") if DEBUG 
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
	puts "#{@xy_x} #{@xy_y} // #{@px} #{@py}" if DEBUG
        parallel_calls(CONFIGURATION['mouse_binding']['lights'].collect { |light| make_color_call(light, [@xy_x,@xy_y]) })
      end
    end
  end
end

def keyboard_input_monitor
  File.open(CONFIGURATION['keyboard_device'], 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      if event.type == 'EV_KEY' && event.data.value == 0
        if mapped_keys.include?(event.code)  
          parallel_calls(perform_action_for(event.code))
        else
          puts "#{event.code} is not a mapped key" if DEBUG
        end
      end
    end
  end
end

get_brightness
pp @brightness if DEBUG
puts "Bound keys: #{mapped_keys.join(",")}" if DEBUG
t3 = Thread.new{mouse_input_monitor} unless CONFIGURATION['mouse_disabled']
t4 = Thread.new{keyboard_input_monitor} unless CONFIGURATION['keyboard_disabled']
t3.join unless CONFIGURATION['mouse_disabled']
t4.join unless CONFIGURATION['keyboard_disabled']
