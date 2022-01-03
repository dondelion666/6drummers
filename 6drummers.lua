local Ack = require 'ack/lib/ack'
engine.name = 'Ack'

local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid
local g = grid.connect()

m=midi.connect()

patterns={}
seqs={}
probs={}
playing=false
clocks={}
current_pattern=1
current_track=1
range_hold=false
seq_hold=false
dx=0
current_page=1

function init()
  
  params:add_file('load_patterns','load patterns',_path.data..'/don/6drummers/')
  params:set_action('load_patterns',function(x) load_patterns(x) end)
  
  params:add_file('save_patterns','save patterns',_path.data..'/don/6drummers/')
  params:set_action('save_patterns',function(x) tab.save(patterns,x)end)
  
  params:add_number('midi_note1','midi note 1',0,127,60)
  params:add_number('midi_note2','midi note 2',0,127,61)
  params:add_number('midi_note3','midi note 3',0,127,62)
  params:add_number('midi_note4','midi note 4',0,127,63)
  params:add_number('midi_note5','midi note 5',0,127,64)
  params:add_number('midi_note6','midi note 6',0,127,65)
  
  
  --initialise patterns
  for i=1,6 do
    patterns[i]={}
    for j=1,6 do
      patterns[i][j]={}
      for k=1,16 do
        patterns[i][j][k]=0
      end
    end
  end
  
  --initialise seqs
  for i=1,6 do
    seqs[i]={}
  end
  
  --initialise probabilities
  for i=1,6 do
    probs[i]={}
  end
  
  engine.loadSample(0, '/home/we/dust/audio/goldeneye/factory/002_goldeneye.wav')
  engine.loadSample(1, '/home/we/dust/audio/goldeneye/factory/003_goldeneye.wav')
  engine.loadSample(2, '/home/we/dust/audio/goldeneye/factory/004_goldeneye.wav')
  engine.loadSample(3, '/home/we/dust/audio/goldeneye/factory/005_goldeneye.wav')
  engine.loadSample(4, '/home/we/dust/audio/goldeneye/factory/006_goldeneye.wav')
  engine.loadSample(5, '/home/we/dust/audio/goldeneye/factory/007_goldeneye.wav')
  
  --redraw clock
  redraw_clock = clock.run(
    function()
      while true do
        clock.sleep(1/15)
        if grid_dirty then
          grid_redraw()
          grid_dirty=false
        end
      end
    end
  )
  
  grid_dirty=true
end

function play(track)
  while playing==true do
      for i=1,#seqs[track] do
        for j=1,#patterns[track][seqs[track][i]] do
          --clock.sync(1/#patterns[track][seqs[track][i]])
          clock.sleep(0.2)
          if patterns[track][seqs[track][i]][j]==1 then
            engine.trig(track-1)
            play_note(track)
          end
        end
      end
  end
end

function play_note(track)
  local note='midi_note'..track
  m:note_on(params:get(note),127,1)
  m:note_off(params:get(note),127,1)
end

function key(n,z)
  if n==2 and z==1 then
    playing=not playing
    if playing==true then
      for i=1,6 do
        if #seqs[i]~=0 then
          clocks[i]=clock.run(play,i)
        end
      end
    elseif playing==false then
      for i=1,6 do
        if #seqs[i]~=0 then
          clock.cancel(clocks[i])
        end
      end
    end
  elseif n==3 and z==1 then
    tab.save(patterns,_path.data..'/don/6drummers/patterns2.txt')
  end
end

function g.key(x,y,z)
  
  --select page
  if y==8 and x==16 and z==1 then
    current_page=util.wrap(current_page+1,1,2)
    grid_dirty=true
    
  --select track
  elseif y==8 and x<=6 and z==1 then
    current_track=x
    grid_dirty=true
    
  --change pattern length
  elseif x==8 and y==8 and z==1 and current_page==1 then
    range_hold=true
    grid_dirty=true
  elseif x==8 and y==8 and z==0 and current_page==1 then
    dx=0
    range_hold=false
    grid_dirty=true
  elseif range_hold==true and y<=6 and z==1 and current_page==1 then
    dx=0
    dx=x-#patterns[current_track][y]
    if dx<0 then
      dx=(dx*-1)-1
      for i=dx,0,-1 do
        local x=#patterns[current_track][y]-i
        patterns[current_track][y][x]=nil
        grid_dirty=true
      end
    elseif dx>0 then
      dx=dx-1
      for i=#patterns[current_track][y],dx+#patterns[current_track][y] do
        patterns[current_track][y][i+1]=0
        grid_dirty=true
      end
    end

  --edit pattern
  elseif y<=6 and z==1 and current_page==1 and range_hold==false then
    patterns[current_track][y][x]=1-patterns[current_track][y][x]
    grid_dirty=true
  
  --edit seq
  elseif y<=6 and z==1 and current_page==2 and range_hold==false then
    if x>#seqs[current_track] then
      seqs[current_track][#seqs[current_track]+1]=7-y
    else seqs[current_track][x]=7-y
    end
    grid_dirty=true
    
  
  --change seq length
  elseif x==8 and y==8 and z==1 and current_page==2 then
    range_hold=true
    grid_dirty=true
  elseif x==8 and y==8 and z==0 and current_page==2 then
    dx=0
    range_hold=false
    grid_dirty=true
  elseif range_hold==true and y<=6 and z==1 and current_page==2 then
    tablecopy={}
    for i=1,x do
      tablecopy[i]=seqs[current_track][i]
    end
    seqs[current_track]={}
    for i=1,#tablecopy do
      seqs[current_track][i]=tablecopy[i]
    end
    grid_dirty=true
    
    
    
  end
end

function grid_redraw()
  g:all(0) -- turn all the LEDs off
  
  --page 1 - patterns
  if current_page==1 then
    
    --draw patterns
    for i=1,6 do
    for j=1,#patterns[current_track][i] do
      if patterns[current_track][i][j]==1 then
        g:led(j,i,patterns[current_track][i][j]*15)
      else g:led(j,i,1)
      end
    end
    end
  
  
    --draw track toolbar
    for i=1,6 do
      g:led(i,8,1)
    end
  
    --draw range button
    if range_hold then
      g:led(8,8,15)
    else g:led(8,8,1)
    end
  
    --current track
    g:led(current_track,8,15)
  
  --page 2 - seqs
  elseif current_page==2 then
    
    --draw track toolbar
    for i=1,6 do
      g:led(i,8,1)
    end
    
    --draw range button
    if range_hold then
      g:led(8,8,15)
    else g:led(8,8,1)
    end
    
    --current track
    g:led(current_track,8,15)
    
    --draw seqs
    for i=1,#seqs[current_track] do
      for j=1,seqs[current_track][i] do
        g:led(i,7-j,1)
      end
      g:led(i,7-seqs[current_track][i],15)
    end
    
  end

  g:refresh() -- refresh the LEDs
  
  grid_dirty = false -- reset the flag because changes have been committed
end

function load_patterns(file)
  patterns=tab.load(file)
  grid_dirty=true
end



function post_patterns()
  --for i=1,6 do
  for j=1,#patterns[1] do
  for k=1,#patterns[j] do
      print('1'..' '..j..' '..patterns[1][j][k])
    end
  end
  --end
end

function post_seqs()
  for i=1,6 do
    for j=1,#seqs[i] do
      print(i..' '..seqs[i][j])
    end
  end
  --end
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
