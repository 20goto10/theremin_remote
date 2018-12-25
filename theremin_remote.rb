require 'rubygems'
require 'device_input'
require 'manticore'
require 'json'

VERSION = 0.21

config_file = File.read('config.json')
CONFIGURATION = JSON.parse(config_file)
BRIGHTNESS_SYNC_PERIOD = 20
MAX_CONCURRENT_REQUESTS = 14
REPEAT_DELAY = 20
DEBUG = !!CONFIGURATION['debug']
DEVICES = CONFIGURATION['devices']
MODE = CONFIGURATION['mode'] # "openhab" or "ha_bridge" 

HUE_RANGE = 360 # can't imagine this changing
SATURATION_RANGE = 100
MAX_BRIGHTNESS = (MODE == 'openhab' ? 100 : 255) 

# for openhab HSB mapping
HUE = 0
SATURATION = 1
BRIGHTNESS = 2

# use two clients because the MOUSE client should wipe out any existing connections each time it sends
CLIENTS = {
  'keyboard' => Manticore::Client.new(request_timeout: 5, connect_timeout: 2, socket_timeout: 2, pool_max: 15, pool_max_per_route: 5),
  'mouse' => Manticore::Client.new(request_timeout: 5, connect_timeout: 2, socket_timeout: 2, pool_max: 15, pool_max_per_route: 5)
}

@px = 0.0
@py = 0.0
@state = {}

def mapped_keys
  @mapped_keys ||= CONFIGURATION['keyboard_bindings'].flat_map { |mapping| mapping['key'] }
end

class String
  def from_hsl
    self.split(',') # maps to HUE,SATURATION,BRIGHTNESS
  end
end

class Array
  def to_hsl
    self.join(',') # maps to "HUE,SATURATION,BRIGHTNESS"
  end
end
          
def random_color(light)
  if MODE == 'openhab'
    random_color = [(rand() * HUE_RANGE).to_i,
                    (rand() * SATURATION_RANGE).to_i,
                    brightness_of(light)].to_hsl
  else
    random_color = [rand(), rand()]
  end
end

def openhab_device_map_for(items)
  CONFIGURATION['openhab_devices'].select { |dev| dev } # TODO 
end

def color_of(key)
  if MODE == 'openhab'
    @state.dig(key.to_i, 'color', HUE).to_f
  else
    @state.dig(key.to_i, 'xy') || 0
  end
end

def saturation_of(key)
  if MODE == 'openhab'
    @state.dig(key.to_i, 'color', SATURATION).to_f  
  else
    MAX_SATURATION
  end
end

def brightness_of(key)
  if MODE == 'openhab'
    (@state.dig(key.to_i, 'color', BRIGHTNESS) || MAX_BRIGHTNESS).to_f
  else
    @state.dig(key.to_i, 'bri') || MAX_BRIGHTNESS
  end
end

def set_on_off(key, val)
  @state[key.to_i] ||= {}
  @state[key.to_i]['on'] = !!val 
end

def is_on?(key)
  @state.dig(key.to_i, 'on') || false
end

def is_off?(key)
  !is_on?(key)
end

def has_color?(key)
  @state.has_key?(key) && (@state[key].has_key?('xy') || @state[key].has_key?('color'))
end

def set_color(key,value)
  @state[key.to_i] ||= {}
  if MODE == 'openhab'
    @state[key.to_i]['color'] ||= []
    @state[key.to_i]['color'][HUE] = value 
  else
    @state[key.to_i]['xy'] = value if value.is_a?(Array) && value.length == 2 && value.all? { |v| v.is_a?(Float) }
  end
end

def set_saturation(key,value)
  @state[key.to_i] ||= {}
  if MODE == 'openhab'
    @state[key.to_i]['color'] ||= []
    @state[key.to_i]['color'][SATURATION] = value.to_i
  else
    @state[key.to_i]['bri'] = value.to_i
  end
end

def set_brightness(key,value)
  @state[key.to_i] ||= {}
  if MODE == 'openhab'
    @state[key.to_i]['color'] ||= []
    @state[key.to_i]['color'][BRIGHTNESS] = value.to_i
  else
    @state[key.to_i]['bri'] = value.to_i
  end
end

def get_state
  puts "Getting state..." if DEBUG
  if MODE == 'openhab'
    CONFIGURATION['openhab_devices'].each do |device|
      result = Manticore.get("#{CONFIGURATION['openhab_url']}/rest/items/#{device['name']}/state")
      @state[device['id']] ||= {}
      @state[device['id']].merge!({ 'color' => result.body.split(",") })   # not sure how to get on/off here; will use self as master decider
    end
  else
    result = Manticore.get("#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights")
    JSON.parse(result.body).each do |k,v|
      @state[k.to_i] = v['state']
    end
  end
end

def openhab_mapping_for(light)
  # provide the label for openhab lights, for the URL, otherwise return self
  CONFIGURATION['openhab_devices'].detect { |dev| dev['id'] == light }['name']
end

def make_dimmer_call(light, intensity)
  if MODE == 'openhab'
    ["#{CONFIGURATION['openhab_url']}/rest/items/#{openhab_mapping_for(light)}", { body: [color_of(light), saturation_of(light), intensity].to_hsl }]
  else
    ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'bri' => intensity }.to_json }]
  end
rescue
  nil
end

def make_color_call(light, values)
  if MODE == 'openhab'
    ["#{CONFIGURATION['openhab_url']}/rest/items/#{openhab_mapping_for(light)}", { body: values }]
  else
    ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'xy': values }.to_json }]
  end
rescue
  nil
end

def make_power_call(light, on_state)
  if MODE == 'openhab'
    ["#{CONFIGURATION['openhab_url']}/rest/items/#{openhab_mapping_for(light)}", { body: (on_state ? "ON" : "OFF" ) }]
  else
    set_brightness(light, 0) if !on_state
    ["#{CONFIGURATION['ha_bridge_url']}/api/#{CONFIGURATION['ha_bridge_username']}/lights/#{light}/state", { body: { 'on': on_state }.to_json }]
  end
rescue
  nil
end

def parallel_calls(datas, client_key)
  if datas
    if client_key == 'mouse'
      CLIENTS[client_key].clear_pending
    end
    datas.compact.each do |data|
      puts "Making call: #{data.join}" if DEBUG
      if MODE == 'openhab'
        response = CLIENTS[client_key].background.parallel.post(*data)
      else
        response = CLIENTS[client_key].background.parallel.put(*data)
      end
      response.on_success do |response|
        puts "SUCCESS: #{JSON.parse(response.body)}" if DEBUG 
      end.on_failure do |response|
        puts "FAILED: #{JSON.parse(response.body)}" if DEBUG 
      end
    end
    CLIENTS[client_key].execute! 
  end
end

def perform_action_for(key, code = 0)
  bindings = CONFIGURATION['keyboard_bindings'].select { |item| item['key'] == key || (item['key'].is_a?(Array) && item['key'].include?(key)) }
  actions = []
  bindings.each do |binding|
    if code == 0 # binding['repeatable'] # TODO: repeating requires awareness of when the key goes down and when up
      puts "Executing: #{binding['name']}" if binding['name'] && DEBUG
      if binding['action'] == 'on' || binding['action'] == 'off' 
        get_state
        actions = binding['lights'].collect do |light| 
          set_on_off(light, binding['action'] == 'on')
          make_power_call(light, binding['action'] == 'on')  
        end
      elsif binding['action'] == 'dim'
        get_state
        actions = binding['lights'].collect do |light| 
          t_bri = brightness_of(light) + (binding['value']  || 0.5)
          set_brightness(light, min_max(t_bri, 0, MAX_BRIGHTNESS))
          make_dimmer_call(light, brightness_of(light).to_i)
        end 
      elsif binding['action'] == 'dim_multiply'
        get_state
        actions = binding['lights'].collect do |light| 
          t_bri = brightness_of(light) * (binding['value'] || 0.5)
          set_brightness(light, min_max(t_bri, (binding['value'].to_f >= 1 ? 16 : 0), MAX_BRIGHTNESS)) # if binding-value is > 1, we mean to raise the brightness, so never let the outcome be 0
          make_dimmer_call(light, brightness_of(light))
        end 
      elsif binding['action'] == 'random'
        actions = binding['lights'].collect { |light| make_color_call(light, random_color(light)) }
      elsif binding['action'] == 'white' || binding['action'] == 'color'
        if MODE == 'ha_bridge'
          col = [0.33333333333, 0.33333333333] 
          if binding['action'] == 'color'
            col[0] = binding['x'] if binding['x'] 
            col[1] = binding['y'] if binding['y'] 
          end
        elsif MODE == 'openhab'
          col = "0,0,100"
        end

        get_state
        actions = binding['lights'].collect do |light| 
          if has_color?(light)
            if MODE == 'openhab' && binding['action'] == 'color'
              h = binding['h'] ? binding['h'] : color_of(light)
              s = binding['s'] ? binding['s'] : saturation_of(light)
              l = binding['l'] ? binding['l'] : brightness_of(light)
              col = [h,s,l].to_hsl
            end
            make_color_call(light, col)
          elsif binding['switches_on']
            make_power_call(light, true)
          end
        end.compact
      elsif binding['action'] == 'toggle'
        # Generally you wouldn't want to actually toggle everything, but rather set them all to the same thing.
        # So, this determines first if any of the lights are currently on, and if so, it turns them off.
        # Otherwise it turns them all on.
        get_state
        anything_on = binding['lights'].any? { |light| is_on?(light) }
        binding['lights'].each { |light| set_on_off(light, !anything_on) }
        actions = binding['lights'].collect { |light| make_power_call(light, !anything_on) } 
      elsif binding['action'] == 'rotate'
        get_state
        target_lights = (binding['reversed'] ? binding['lights'].reverse : binding['lights'])
        color = color_of(target_lights.last)
        actions = target_lights.collect do |light| 
          new_color_xy = color
          color = color_of(light)
	  puts "#{light}: #{new_color_xy} / old color #{color}"
          set_color(light, new_color_xy)
          make_color_call(light, new_color_xy)
        end
      elsif binding['action'] == 'custom'
        puts "Custom action #{binding['eval']}" if DEBUG
        if binding['state_url']
          state = JSON.parse(Manticore.send((binding['state_method'] || 'get').to_sym, binding['state_url']).body)[(binding['state_variable'] || 'state')]
          puts "Current state is #{state}" if DEBUG
          new_state = eval(binding['eval'])
        else
          new_state = binding['body']
        end
        puts "New state will be #{new_state}" if DEBUG
        chain = binding['chain'] ? binding['chain'] : [binding] 
        chain.each do |item|
          Manticore.send((item['method'] || 'post').to_sym, item['url'], { body: (item['body'] || new_state).to_s  }).call
          sleep(item['delay'] || 0.2)
        end
      end
    end
  end
  actions
end

def min_max(val,min,max) 
  a = val < min ? min : val
  a > max ? max : a
end
          
def mouse_xy(event)
  get_state
  CONFIGURATION['mouse_binding']['lights'].collect do |light| 
    new_x = new_y = 0
    if (event.code == "X")
      new_x = color_of(light)[0] + (event.data.value.to_f / CONFIGURATION['max_x_resolution'])
      new_y = color_of(light)[1]
    end
    if (event.code == "Y")
      new_x = color_of(light)[0]
      new_y = color_of(light)[1] - (event.data.value.to_f / CONFIGURATION['max_y_resolution']) # the operator is a - because Y is inverted (0,0 is the top left corner)
    end
    if CONFIGURATION['drift']
      new_x += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
      new_y += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
    end 
    new_xy = [min_max(new_x,0,1.0),min_max(new_y,0,1.0)] 
    set_color(light, new_xy)
    make_color_call(light, new_xy)
  end
end

def mouse_hsl(event)
  get_state
  CONFIGURATION['mouse_binding']['lights'].collect do |light| 
    new_h = new_s = 0
    if (event.code == "X")
      new_h = color_of(light) + 360 * (event.data.value.to_f / CONFIGURATION['max_x_resolution'])
      new_s = saturation_of(light)
    end
    if (event.code == "Y")
      new_h = color_of(light)
      new_s = saturation_of(light) + 100 * (event.data.value.to_f / CONFIGURATION['max_y_resolution']) 
    end
    if CONFIGURATION['drift']
      new_h += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
      new_s += (rand() * CONFIGURATION['drift'] * 2) - CONFIGURATION['drift']
    end 
    new_hue = min_max(new_h,0,359.99)
    new_saturation = min_max(new_s,0,100.0)
    new_brightness = brightness_of(light)

    set_color(light, new_hue)
    set_saturation(light, new_saturation)
    make_color_call(light, [new_hue, new_saturation, new_brightness].to_hsl)
  end
end

def input_monitor(device)
  File.open(device, 'r') do |dev|
    DeviceInput.read_loop(dev) do |event|
      if event.type == 'EV_KEY' && !CONFIGURATION['keyboard_disabled'] # KEYBOARD DEVICES
        if mapped_keys.include?(event.code)  
          calls = parallel_calls(perform_action_for(event.code, event.data.value), 'keyboard')
        else
          puts "#{event.code} is not a mapped key" if DEBUG
        end
      elsif !CONFIGURATION['mouse_disabled']
        puts "Moved by #{event.data.value.to_f}" if (event.code == "X" || event.code == "Y") if DEBUG 

        if (['X','Y'].include?(event.code))
          if CONFIGURATION['mouse_effect'] == 'xy'
            calls = mouse_xy(event)
          elsif CONFIGURATION['mouse_effect'] != 'none'
            calls = mouse_hsl(event)
          end
        end
        parallel_calls(calls, 'mouse')
      end
    end
  end
end

def start
  puts "Bound keys: #{mapped_keys.join(",")}" if DEBUG
  threads = []
  DEVICES.each_index do |i|
    threads.push(Thread.new(i) do 
      puts "Adding device #{DEVICES[i]}" if DEBUG
      loop do
        begin
          input_monitor(DEVICES[i])
        rescue => e
          puts "** ERROR! #{e.message} **"
          puts e.backtrace.join("\n")
          puts "** END OF ERROR **"
        end
      end
    end)
  end
  DEVICES.each_index { |i| threads[i].join }
end

start
