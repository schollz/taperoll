-- new script v0.0.1
-- ?
--
-- llllllll.co/t/?
--
--
--
--    ▼ instructions below ▼
--
-- ?

local seconds_max=250
playpos={
  rec=0,
  current=0,
  new=0,
  update=0,
  tt={},
  tt_start_beats=0,
  tt_start_time=0,
}
local position_changed=false
local shift=false
do_loop=0

function init()
  -- initialize array to hold the current times
  playpos.tt={}
  for i=0,seconds_max do 
    table.insert(playpos.tt,0)
  end

  -- initialize softcut
  init_softcut()

  -- init parameters
  params:add_control("rate","rate",controlspec.new(-1,1,'lin',0.01,1,'s',0.01/2))
  params:set_action("rate",function(x)
    rate(x)
  end)
  params:add_control("position","position",controlspec.new(0,seconds_max,'lin',0.05,0,'s',0.05/seconds_max))
  params:set_action("position",function(x)
    position_changed=true
    pos(x)
  end)
  params:add_control("loop1","loop start",controlspec.new(0,seconds_max,'lin',0.05,0,'s',0.05/seconds_max))
  params:set_action("loop1",function(x)
    if playpos.current<params:get("loop2") then 
      loop(x,params:get("loop2"))
    end
  end)
  params:add_control("loop2","loop end",controlspec.new(0,seconds_max,'lin',0.05,1,'s',0.05/seconds_max))
  params:set_action("loop2",function(x)
    loop(params:get("loop1"),x)
  end)


  -- initialize metro for updating screen
  timer=metro.init()
  timer.time=1/15
  timer.count=-1
  timer.event=run_updater
  timer:start()

  debounce_start=15
end


function init_softcut()
  -- setup three stereo loops
  softcut.reset()
  softcut.buffer_clear()
  audio.level_eng_cut(0)
  audio.level_tape_cut(1)
  audio.level_adc_cut(1)
  for i=1,4 do
    softcut.enable(i,1)

    -- stereo loops
    if i%2==1 then
      softcut.pan(i,1)
      softcut.buffer(i,1)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,0)
    else
      softcut.pan(i,-1)
      softcut.buffer(i,2)
      softcut.level_input_cut(1,i,0)
      softcut.level_input_cut(2,i,1)
    end

    if i>2 then
      -- recording heads
      softcut.rec(i,1)
      softcut.level(i,0.0)
      softcut.rec_level(i,1.0)
      softcut.pre_level(i,0.0)
    else
      -- playback heads
      softcut.rec(i,0)
      softcut.level(i,1.0)
      softcut.rec_level(i,0.0)
      softcut.pre_level(i,1.0)
    end
    softcut.play(i,1)
    softcut.rate(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,seconds_max)
    softcut.position(i,0)
    softcut.loop(i,1)
    softcut.fade_time(i,0.1)

    softcut.level_slew_time(i,0.4)
    softcut.rate_slew_time(i,0.4)
    softcut.pan_slew_time(i,0.4)
    softcut.recpre_slew_time(i,0.4)

    softcut.phase_quant(i,0.025)

    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_rq(i,1.0)
    softcut.post_filter_fc(i,20000)

    softcut.pre_filter_dry(i,1.0)
    softcut.pre_filter_lp(i,1.0)
    softcut.pre_filter_rq(i,1.0)
    softcut.pre_filter_fc(i,20000)
  end
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  playpos.tt[1]=ct()
  playpos.tt_start_beats=playpos.tt[1]
  playpos.tt_start_time=os.time()
end

function ct()
  return clock.get_beats()*clock.get_beat_sec()
end

function update_positions(voice,position)
  if voice==3 then 
    playpos.tt[math.floor(position)+1]=ct()
    playpos.rec=position
  elseif voice==1 then 
    playpos.current=position
    if playpos.update==0 and not position_changed then
      params:set("position",position,true)
    end
  end
end

function run_updater()
  -- TODO: reset position_changed after awhile
  if debounce_start>0 then 
    debounce_start=debounce_start-1
    if debounce_start==0 then 
      frontier()
    end
  end
  if playpos.update>0 then 
    playpos.update=playpos.update-1
    if playpos.update==0 then 
      for i=1,2 do 
        softcut.position(i,playpos.new)
      end
    end
  end
  redraw()
end

function frontier()
  position_changed=false
  loop(0,seconds_max)
  pos(playpos.rec-1)
end

function pos(pos)
  playpos.update=1
  playpos.new=pos
end

function loop(pos1,pos2)
  local p1=pos1
  local p2=pos2
  if p1>p2 then 
    p1=pos2 
    p2=pos1
  end
  for i=1,2 do 
    softcut.loop_start(i,p1)
    softcut.loop_end(i,p2)
  end
end

function rate(r)
  for i=1,2 do 
    softcut.rate(i,r)
  end
end

function key(k,z)
  if k==1 then
    shift=z==1
  end
  if shift and z==1 then
    if k==1 then
    elseif k==2 then
    else
    end
  elseif z==1 then
    if k==1 then
    elseif k==2 then
      position_changed=false
      if do_loop==0 then 
        params:set("loop1",playpos.current)
      elseif do_loop==1 then 
        params:set("loop2",playpos.current) 
      else 
        -- TODO: some weird bug happens when making loops going backwards
        if params:get("rate")<0 then 
          params:set("loop2",0)
        else
          params:set("loop2",seconds_max)
        end
        do_loop=-1
      end
      do_loop=do_loop+1
    elseif k==3 then
      frontier()
    end
  end
end

function enc(k,d)
  if shift then
    if k==1 then
    elseif k==2 then
    elseif k==3 then 
    end
  else
    if k==1 then
    elseif k==2 then
      params:delta("rate",d)
    elseif k==3 then
      params:delta("position",d)
      params:set("loop1",params:get("position"))
      if params:get("loop2")<params:get("loop1") then 
        params:set("loop2",params:get("loop1")+1)
      end
    end
  end
end

function in_loop()
  if params:get("loop2")==seconds_max then 
    return false
  end
  return playpos.current>=params:get("loop1") and playpos.current<=params:get("loop2")
end

function redraw()
  screen.clear()
  local current=playpos.current 
  if playpos.update>0 then 
    current=playpos.new
  end
  local m=playpos.tt[math.floor(current)+1]
  local f=current-math.floor(current)
  local n=playpos.tt[math.floor(current)+2]
  if n==nil then 
    n=m+1
  end
  if m~=nil then
    m=m*(1-f)+n*f
    local tt=m-playpos.tt_start_beats+playpos.tt_start_time
    local mtt=math.floor(tt)
    screen.font_face(40)
    screen.move(10,10)
    screen.font_size(12)
    screen.text(os.date('%B %d',mtt))
    screen.move(10,30)
    local ss=string.format("%.2f",tt-mtt)
    ss=ss:sub(2)
    screen.font_face(5)
    screen.font_size(22)
    screen.text(os.date('%I:%M:%S', mtt)..ss)
  end
  screen.update()
end

function rerun()
  norns.script.load(norns.state.script)
end



