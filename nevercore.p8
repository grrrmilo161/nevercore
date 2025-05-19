pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- [initialization]
-- evercore v2.3.1
-- nevercore v0.0.1

shieldcoins={}
allcollected=false

function vector(x,y)
	return {x=x,y=y}
end

function rectangle(x,y,w,h)
	return {x=x,y=y,w=w,h=h}
end

-- global tables
objects,collected={},{}
-- global timers
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
-- global camera values
draw_x,draw_y,cam_x,cam_y,cam_spdx,cam_spdy,cam_gain=0,0,0,0,0,0,0.25

-- [entry point]

function _init()
	frames,start_game_flash=0,0
	music(40,0,7)
	lvl_id=0
end

function begin_game()
	max_djump=1
	deaths,frames,seconds_f,minutes,music_timer,time_ticking,fruit_count,bg_col,cloud_col=0,0,0,0,0,true,0,0,1
	music(0,0,7)
	load_level(1)
end

function is_title()
	return lvl_id==0
end

-- [effects]

clouds={}
for i=0,16 do
	add(clouds,{
		x=rnd"128",
		y=rnd"128",
		spd=1+rnd"4",
	w=32+rnd"32"})
end

particles={}
for i=0,24 do
	add(particles,{
		x=rnd"128",
		y=rnd"128",
		s=flr(rnd"1.25"),
		spd=0.25+rnd"5",
		off=rnd(),
		c=6+rnd"2",
	})
end

dead_particles={}

-- [function library]

function psfx(num)
	if sfx_timer<=0 then
		sfx(num)
	end
end

function round(x)
	return flr(x+0.5)
end

function appr(val,target,amount)
	return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
	return v~=0 and sgn(v) or 0
end

function two_digit_str(x)
	return x<10 and "0"..x or x
end

function tile_at(x,y)
	return mget(lvl_x+x,lvl_y+y)
end

function spikes_at(x1,y1,x2,y2,xspd,yspd)
	for i=max(0,x1\8),min(lvl_w-1,x2/8) do
		for j=max(0,y1\8),min(lvl_h-1,y2/8) do
			if({[17]=y2%8>=6 and yspd>=0,
			[27]=y1%8<=2 and yspd<=0,
			[43]=x1%8<=2 and xspd<=0,
			[59]=x2%8>=6 and xspd>=0})[tile_at(i,j)] then
				return true
			end
		end
	end
end
-->8
-- [update loop]

function _update()
	frames+=1
	if time_ticking then
		seconds_f+=1
		minutes+=seconds_f\1800
		seconds_f%=1800
	end
	frames%=30

	if music_timer>0 then
		music_timer-=1
		if music_timer<=0 then
			music(10,0,7)
		end
	end

	if sfx_timer>0 then
		sfx_timer-=1
	end

	-- cancel if freeze
	if freeze>0 then
		freeze-=1
		return
	end

	-- restart (soon)
	if delay_restart>0 then
		cam_spdx,cam_spdy=0,0
		delay_restart-=1
		if delay_restart==0 then
			load_level(lvl_id)
		end
	end

	-- update each object
	foreach(objects,function(obj)
		obj.move(obj.spd.x,obj.spd.y,0);
		(obj.type.update or stat)(obj)
	end)

	-- move camera to player
	foreach(objects,function(obj)
		if obj.type==player or obj.type==player_spawn then
			move_camera(obj)
		end
	end)

	-- start game
	if is_title() then
		if start_game then
			start_game_flash-=1
			if start_game_flash<=-30 then
				begin_game()
			end
		elseif btn(🅾️) or btn(❎) then
			music"-1"
			start_game_flash,start_game=50,true
			sfx"38"
		end
	end
end
-->8
-- [draw loop]

function _draw()
	if freeze>0 then
		return
	end

	-- reset all palette values
	pal()

	-- start game flash
	if is_title() then
		if start_game then
			for i=1,15 do
				pal(i, start_game_flash<=10 and ceil(max(start_game_flash)/5) or frames%10<5 and 7 or i)
			end
		end

		cls()

		-- credits
		sspr(unpack(split"72,32,56,32,36,32"))
		?"🅾️/❎",55,80,5
		?"maddy thorson",40,96,5
		?"noel berry",46,102,5

		-- particles
		foreach(particles,draw_particle)

		return
	end

	-- draw bg color
	cls(flash_bg and frames/5 or bg_col)

	-- bg clouds effect
	foreach(clouds,function(c)
		c.x+=c.spd-cam_spdx
		rectfill(c.x,c.y,c.x+c.w,c.y+16-c.w*0.1875,cloud_col)
		if c.x>128 then
			c.x=-c.w
			c.y=rnd"120"
		end
	end)

	-- set cam draw position
	draw_x=round(cam_x)-64
	draw_y=round(cam_y)-64
	camera(draw_x,draw_y)

	-- draw bg terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
	
	-- set draw layering
	-- positive layers draw after player
	-- layer 0 draws before player, after terrain
	-- negative layers draw before terrain
	local pre_draw,post_draw={},{}
	foreach(objects,function(obj)
		local draw_grp=obj.layer<0 and pre_draw or post_draw
		for k,v in ipairs(draw_grp) do
			if obj.layer<=v.layer then
				add(draw_grp,obj,k)
				return
			end
		end
		add(draw_grp,obj)
	end)

	-- draw bg objects
	foreach(pre_draw,draw_object)
	
	-- draw terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
	
	-- draw fg objects
	foreach(post_draw,draw_object)

	-- draw jumpthroughs
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)

	-- particles
	foreach(particles,draw_particle)

	-- dead particles
	foreach(dead_particles,function(p)
		p.x+=p.dx
		p.y+=p.dy
		p.t-=0.2
		if p.t<=0 then
			del(dead_particles,p)
		end
		rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
	end)

	-- draw level title
	camera()
	if ui_timer>=-30 then
		if ui_timer<0 then
			draw_ui()
		end
		ui_timer-=1
	end
end

function draw_particle(p)
	p.x+=p.spd-cam_spdx
	p.y+=sin(p.off)-cam_spdy
	p.off+=min(0.05,p.spd/32)
	rectfill(p.x+draw_x,p.y%128+draw_y,p.x+p.s+draw_x,p.y%128+p.s+draw_y,p.c)
	if p.x>132 then
		p.x=-4
		p.y=rnd"128"
	elseif p.x<-4 then
		p.x=128
		p.y=rnd"128"
	end
end

function draw_time(x,y)
	rectfill(x,y,x+44,y+6,0)
	?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds_f\30).."."..two_digit_str(round(seconds_f%30*100/30)),x+1,y+1,7
end

function draw_ui()
	rectfill(24,58,104,70,0)
	local title=lvl_title or lvl_id.."00 m"
	?title,64-#title*2,62,7
	draw_time(4,4)
end
-->8
-- [player class]

player={
	init=function(this)
		this.grace,this.jbuffer=0,0
		this.djump=max_djump
		this.dash_time,this.dash_effect_time=0,0
		this.dash_target_x,this.dash_target_y=0,0
		this.dash_accel_x,this.dash_accel_y=0,0
		this.hitbox=rectangle(1,3,6,5)
		this.spr_off=0
		this.collides=true
		this.in_bubble=false
		create_hair(this)
		
		this.layer=1
	end,
	update=function(this)
		if pause_player then
			return
		end
		if this.in_bubble then
			this.spd.x = 0
			this.spd.y = 0
			return
		end
		-- horizontal input
		local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

		-- spike collision / bottom death
		if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or this.y>lvl_ph then
			kill_player(this)
		end

		-- on ground checks
		local on_ground=this.is_solid(0,1)

		-- landing smoke
		if on_ground and not this.was_on_ground then
			this.init_smoke(0,4)
		end

		-- jump and dash input
		local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
		this.p_jump,this.p_dash=btn(🅾️),btn(❎)

		-- jump buffer
		if jump then
			this.jbuffer=4
		elseif this.jbuffer>0 then
			this.jbuffer-=1
		end

		-- grace frames and dash restoration
		if on_ground then
			this.grace=6
			if this.djump<max_djump then
				psfx"54"
				this.djump=max_djump
			end
		elseif this.grace>0 then
			this.grace-=1
		end

		-- dash effect timer (for dash-triggered events, e.g., berry blocks)
		this.dash_effect_time-=1

		-- dash startup period, accel toward dash target speed
		if this.dash_time>0 then
			this.init_smoke()
			this.dash_time-=1
			this.spd=vector(appr(this.spd.x,this.dash_target_x,this.dash_accel_x),appr(this.spd.y,this.dash_target_y,this.dash_accel_y))
		else
				-- x movement
				local maxrun=1
				local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
				local deccel=0.15

				-- set x speed
				this.spd.x=abs(this.spd.x)<=1 and
				appr(this.spd.x,h_input*maxrun,accel) or
				appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

				-- facing direction
				if this.spd.x~=0 then
					this.flip.x=this.spd.x<0
				end

				-- y movement
				local maxfall=2

				-- wall slide
				if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
					maxfall=0.4
					-- wall slide smoke
					if rnd"10"<2 then
						this.init_smoke(h_input*6)
					end
				end

				-- apply gravity
				if not on_ground then
					this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
				end

				-- jump
				if this.jbuffer>0 then
					if this.grace>0 then
						-- normal jump
						psfx"1"
						this.jbuffer=0
						this.grace=0
						this.spd.y=-2
						this.init_smoke(0,4)
					else
						-- wall jump
						local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
						if wall_dir~=0 then
							psfx"2"
							this.jbuffer=0
							this.spd=vector(wall_dir*(-1-maxrun),-2)
							if not this.is_ice(wall_dir*3,0) then
								-- wall jump smoke
								this.init_smoke(wall_dir*6)
							end
						end
					end
			end

			-- dash
			local d_full=5
			local d_half=3.5355339059 -- 5 * sqrt(2)

			if this.djump>0 and dash then
				this.init_smoke()
				this.djump-=1
				this.dash_time=4
				has_dashed=true
				this.dash_effect_time=10
				-- vertical input
				local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
				-- calculate dash speeds
				this.spd=vector(h_input~=0 and
					h_input*(v_input~=0 and d_half or d_full) or
					(v_input~=0 and 0 or this.flip.x and -1 or 1)
				,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
				-- effects
				psfx"3"
				freeze=2
				-- dash target speeds and accels
				this.dash_target_x=2*sign(this.spd.x)
				this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
				this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
				this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
			elseif this.djump<=0 and dash then
				-- failed dash smoke
				psfx"9"
				this.init_smoke()
			end
		end

		-- animation
		this.spr_off+=0.25
		this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or	-- wall slide or mid air
		btn(⬇️) and 6 or -- crouch
		btn(⬆️) and 7 or -- look up
		this.spd.x~=0 and h_input~=0 and 1+this.spr_off%4 or 1 -- walk or stand

		-- exit level off the top (except summit)
		if this.y<-4 and levels[lvl_id+1] then
			next_level()
		end

		-- was on the ground
		this.was_on_ground=on_ground
	end,

	draw=function(this)
		-- clamp in screen
		local clamped=mid(this.x,-1,lvl_pw-7)
		if this.x~=clamped then
			this.x=clamped
			this.spd.x=0
		end
		-- draw player hair and sprite
		set_hair_color(this.djump)
		if not this.in_bubble do 
			draw_hair(this)
			draw_obj_sprite(this)
		end
		pal()
		print(this.djump, this.x,this.y,14)
		print(this.p_dash, this.x,55,14)
	end
}

function create_hair(obj)
	obj.hair={}
	for i=1,5 do
		add(obj.hair,vector(obj.x,obj.y))
	end
end

function set_hair_color(djump)
	pal(8,djump==1 and 8 or djump==2 and 7+frames\3%2*4 or 12)
end

function draw_hair(obj)
	local last=vector(obj.x+(obj.flip.x and 6 or 2),obj.y+(btn(⬇️) and 4 or 3))
	for i,h in ipairs(obj.hair) do
		h.x+=(last.x-h.x)/1.5
		h.y+=(last.y+0.5-h.y)/1.5
		circfill(h.x,h.y,mid(4-i,1,2),8)
		last=h
	end
end

function kill_player(obj)
	sfx_timer=12
	sfx"0"
	deaths+=1
	destroy_object(obj)
	for dir=0,0.875,0.125 do
		add(dead_particles,{
			x=obj.x+4,
			y=obj.y+4,
			t=2,
			dx=sin(dir)*3,
			dy=cos(dir)*3
		})
	end
	delay_restart=15
end

player_spawn={
	init=function(this)
        allcollected=false
        shieldcoins={}
        shieldleftcounter=0
        shieldtopcounter=0
        shield_targetx=0
        shield_targety=0
		sfx"4"
		this.spr=3
		this.target=this.y
		this.y=min(this.y+48,lvl_ph)
		cam_x,cam_y=mid(this.x+4,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
		this.spd.y=-4
		this.state=0
		this.delay=0
		create_hair(this)
		this.djump=max_djump
		
		this.layer=1
	end,
	update=function(this)
		-- jumping up
		if this.state==0 and this.y<this.target+16 then
			this.state=1
			this.delay=3
			-- falling
		elseif this.state==1 then
			this.spd.y+=0.5
			if this.spd.y>0 then
				if this.delay>0 then
					-- stall at peak
					this.spd.y=0
					this.delay-=1
				elseif this.y>this.target then
					-- clamp at target y
					this.y=this.target
					this.spd=vector(0,0)
					this.state=2
					this.delay=5
					this.init_smoke(0,4)
					sfx"5"
				end
			end
			-- landing and spawning player object
		elseif this.state==2 then
			this.delay-=1
			this.spr=6
			if this.delay<0 then
				destroy_object(this)
				init_object(player,this.x,this.y)
			end
		end
	end,
	draw= player.draw
}
-->8
-- [objects]

spring={
	init=function(this) 
		this.delta=0
		this.dir=this.spr==18 and 0 or this.is_solid(-1,0) and 1 or -1
		this.show=true
		this.layer=-1
	end,
	update=function(this)
		this.delta=this.delta*0.75
		local hit=this.player_here()
		
		if this.show and hit and this.delta<=1 then
			if this.dir==0 then
				hit.move(0,this.y-hit.y-4,1)
				hit.spd.x*=0.2
				hit.spd.y=-3
			else
				hit.move(this.x+this.dir*4-hit.x,0,1)
				hit.spd=vector(this.dir*3,-1.5)
			end
			hit.dash_time=0
			hit.dash_effect_time=0
			hit.djump=max_djump
			this.delta=8
            psfx"8"
			this.init_smoke()
			
			break_fall_floor(this.check(fall_floor,-this.dir,this.dir==0 and 1 or 0))
		end
	end,
	draw=function(this)
		if this.show then
			local delta=min(flr(this.delta),4)
			if this.dir==0 then
				sspr(16,8,8,8,this.x,this.y+delta)
			else
				spr(19,this.dir==-1 and this.x+delta or this.x,this.y,1-delta/8,1,this.dir==1)
			end
		end
end
}

fall_floor={
	init=function(this)
		this.solid_obj=true
		this.state=0
	end,
	update=function(this)
		-- idling
		if this.state==0 then
			for i=0,2 do
				if this.check(player,i-1,-(i%2)) then
					break_fall_floor(this)
				end
			end
		-- shaking
		elseif this.state==1 then
			this.delay-=1
			if this.delay<=0 then
				this.state=2
				this.delay=60 -- how long it hides for
				this.collideable=false
				set_springs(this,false)
			end
			-- invisible, waiting to reset
		elseif this.state==2 then
			this.delay-=1
			if this.delay<=0 and not this.player_here() then
				psfx"7"
				this.state=0
				this.collideable=true
				this.init_smoke()
				set_springs(this,true)
			end
		end
	end,
	draw=function(this)
		if this.state~=2 then
			spr(this.state==1 and 26-this.delay/5 or 23,this.x,this.y)
		end
	end,
}

function break_fall_floor(obj)
	if obj and obj.state==0 then
		psfx"15"
		obj.state=1
		obj.delay=15 -- time until it falls
		obj.init_smoke()
	end
end

function set_springs(obj,state)
	obj.hitbox=rectangle(-2,-2,12,8)
	local springs=obj.check_all(spring,0,0)
	foreach(springs,function(s) s.show=state end)
	obj.hitbox=rectangle(0,0,8,8)
end

shieldcoin={
	init=function(this)
		this.timer=0
		this.maxtimer=30
		this.collected=false
		add(shieldcoins, this)
	end,
	update=function(this)    
		if not this.collected do
			local hit=this.player_here()
			if hit do
				this.collected=true
				this.init_smoke()
                this.maxtimer=16
				allcollected=true
                psfx"23"
				for coin in all(shieldcoins) do
					if coin.collected==false do
						allcollected=false
					end
				end
                if allcollected do
                    for coin in all(shieldcoins) do
                        coin.init_smoke()
                    end
                    sfx"63"
                end
			end
		end
		this.timer = (this.timer + 1) % this.maxtimer
	end,
	draw=function(this)
		if allcollected then
            pal(12,2)
        elseif this.collected then
            pal(12,7)
        end
		if this.timer<=(this.maxtimer/2) and not allcollected do
			this.spr=67
		else
			this.spr=66
		end
		draw_obj_sprite(this)
		pal()
	end
}

function draw_block(this)
    local cols = shieldtopcounter + 1
    local rows = shieldleftcounter + 1
    local sx = this.shake_offset_x or 0
    local sy = this.shake_offset_y or 0

    for dy=0,rows-1 do
        for dx=0,cols-1 do
			--pal(1,7)
            local x = this.x + dx*8 + sx
            local y = this.y + dy*8 + sy
            local sprite, fx, fy = 40, false, false

            local l, r, t, b = dx==0, dx==cols-1, dy==0, dy==rows-1

            if t and l then sprite=82
            elseif t and r then sprite,fx=82,true
            elseif b and l then sprite,fy=82,true
            elseif b and r then sprite,fx,fy=82,true,true
            elseif t then sprite=83
            elseif b then sprite,fy=83,true
            elseif l then sprite=98
            elseif r then sprite,fx=98,true
            else pal(5,1)
            end
            spr(sprite, x, y, 1, 1, fx, fy)
            pal()
        end
    end

    -- center sprite
    spr(99, this.x + cols*4 - 4 + sx, this.y + rows*4 - 4 + sy)
end

function move_block(this, targetx, targety, speed)
	local dx = mid(-speed, targetx - this.x, speed)
	local dy = mid(-speed, targety - this.y, speed)
	this.move(dx, dy, 1)
end


shield_top = {
	init = function(this)
        shieldtopcounter+=1
		destroy_object(this)
	end
}

shield_left = {
	init = function(this) 
        shieldleftcounter+=1
		destroy_object(this)
	end
}

shield_corner = {
	init = function(this)
		this.solid_obj = true
		this.moved = false
		this.shake_timer = 10
		this.shake_offset_x = 0
		this.shake_offset_y = 0
	end,

	update = function(this)
		this.moved = this.x == shield_targetx and this.y == shield_targety

		if allcollected and not this.moved then
			if this.shake_timer > 0 then
				this.shake_offset_x = rnd(1) - 0.5
				this.shake_offset_y = rnd(1) - 0.5
				this.shake_timer -= 1
			else
				this.shake_offset_x = 0
				this.shake_offset_y = 0

				local dx = shield_targetx - this.x
				local dy = shield_targety - this.y

				if abs(dx) < 0.5 and abs(dy) < 0.5 then
					this.x = shield_targetx
					this.y = shield_targety
					this.moved = true
				else
					-- full intended speed (easing + nudge)
					local spd_x = dx * 0.15 + sign(dx) * 0.5
					local spd_y = dy * 0.15 + sign(dy) * 0.5

					-- clamp overall speed to max
					local mag = sqrt(spd_x * spd_x + spd_y * spd_y)
					local max_speed = 2
					if mag > max_speed then
						local scale = max_speed / mag
						spd_x *= scale
						spd_y *= scale
					end

					this.move(spd_x, spd_y, 1)
				end
			end
		end

		this.hitbox.w = (shieldtopcounter + 1) * 8
		this.hitbox.h = (shieldleftcounter + 1) * 8
	end,

	draw = function(this)
		draw_block(this)
	end
}


counternew=0

gbubble = {
	init=function(this)
		this.hitbox = rectangle(-1,-1,10,10)
		this.homex,this.homey = this.x,this.y
		this.cooldown = 60
		this.maxcooldown = 60
		this.autoeject = 30
		this.ejectcounter = this.autoeject
		this.moving = false
		this.move_dir = {x=0,y=0}
		this.move_dist = 0
		this.active = true
		this.has_player = false
		this.layer = 3
	end,

	update=function(this)
		local p = this.player_here()

		if not this.active and not this.has_player and not this.moving then
			this.cooldown = max(0,this.cooldown-1)
			if this.cooldown == 0 then
				this.active = true
				this.cooldown = this.maxcooldown
			end

		elseif this.moving then
			this.x += this.move_dir.x * 3
			this.y += this.move_dir.y * 3
			this.move_dist -= 3
			if this.has_player and p then
				p.x, p.y = this.x, this.y
			end
			if this.move_dist <= 0 then
				this.moving = false
				this.active = false
				this.has_player = false
				this.x, this.y = this.homex, this.homey
				this.cooldown = this.maxcooldown
				if p then
					p.in_bubble = false
					p.djump = max_djump
					p.dash_time=0
				end
			end

		elseif this.has_player then
			this.ejectcounter -= 1
			if p and (btnp(❎) or this.ejectcounter <= 0) then
				local dx = (btn(➡️) and 1 or 0) - (btn(⬅️) and 1 or 0)
				local dy = (btn(⬇️) and 1 or 0) - (btn(⬆️) and 1 or 0)
				if dx == 0 and dy == 0 then dx = 1 end
				local mag = sqrt(dx*dx + dy*dy)
				this.move_dir = {x=dx/mag, y=dy/mag}
				this.moving = true
				this.move_dist = 28 -- total pixels (3px * 12 frames)
			end

		elseif p then
			this.ejectcounter = this.autoeject
			if not this.has_player then
				this.has_player = true
				p.in_bubble = true
				local eject_speed=50
				p.spd.x = this.move_dir.x * eject_speed
				p.spd.y = this.move_dir.y * eject_speed
				p.x, p.y = this.x, this.y
			end

		elseif this.has_player then
			this.has_player = false
			this.active = false
		end
	end,

	draw=function(this)
		this.spr = this.active and 114 or 116
		draw_obj_sprite(this)
	end
}




rbubble = {
	init=function(this)
		this.timer=0
		this.cooldown=60
		this.active=true
		this.hitbox=rectangle(-1,-1,10,10)
		this.layer=3
		this.has_player=false
	end,
	update=function(this)
		if this.active==false and not this.has_player do
			if this.timer==this.cooldown do
				this.timer=0
				this.active=true
			else
				this.timer+=1
			end
		elseif not this.has_player do
			local p=this.player_here()
			if p do
				p.in_bubble=true
				this.has_player=true
			end
		elseif this.has_player and dash do
			counternew+=1
		end
	end,
	draw=function(this)
		if not this.active do this.spr=116 else this.spr=115 end
		draw_obj_sprite(this)
	end
}

singlecrystal={
	init=function(this)
		this.activestate=true
		this.start=this.y
		this.timer=0
		this.hitbox=rectangle(-1,-1,10,10)
		this.cooldown=60
	end,
	update=function(this)
		if this.spr==22 then
			local hit=this.player_here()
			if hit and hit.djump<max_djump then
				sfx"6"
				this.init_smoke()
				hit.djump=max_djump
				this.timer=this.cooldown
				this.activestate=false
			end
		elseif this.timer>0 then
			this.timer-=1
		else
			sfx"7"
			this.init_smoke()
			this.activestate=true
		end
		if this.activestate==true then
			this.spr=22
		else
			this.spr=21
		end
	end,
	draw=function(this)
		draw_obj_sprite(this)
	end
}

smoke={
	init=function(this)
		this.spd=vector(0.3+rnd"0.2",-0.1)
		this.x+=-1+rnd"2"
		this.y+=-1+rnd"2"
		this.flip=vector(rnd()<0.5,rnd()<0.5)
		this.layer=3
	end,
	update=function(this)
		this.spr+=0.2
		if this.spr>=32 then
			destroy_object(this)
		end
	end
}

fruit={
	is_fruit=true,
	init=function(this)
		this.start=this.y
		this.off=0
	end,
	update=function(this)
		check_fruit(this)
		this.off+=0.025
		this.y=this.start+sin(this.off)*2.5
	end
}

fly_fruit={
	is_fruit=true,
	init=function(this)
		this.start=this.y
		this.step=0.5
		this.sfx_delay=8
	end,
	update=function(this)
		-- fly away
		if has_dashed then
			if this.sfx_delay>0 then
				this.sfx_delay-=1
				if this.sfx_delay<=0 then
					sfx_timer=20
					sfx"14"
				end
			end
			this.spd.y=appr(this.spd.y,-3.5,0.25)
			if this.y<-16 then
				destroy_object(this)
			end
			-- wait
		else
			this.step+=0.05
			this.spd.y=sin(this.step)*0.5
		end
		-- collect
		check_fruit(this)
	end,
	draw=function(this)
		spr(26,this.x,this.y)
		for ox=-6,6,12 do
			spr((has_dashed or sin(this.step)>=0) and 45 or this.y>this.start and 47 or 46,this.x+ox,this.y-2,1,1,ox==-6)
		end
	end
}

function check_fruit(this)
	local hit=this.player_here()
	if hit then
		hit.djump=max_djump
		sfx_timer=20
		sfx"13"
		collected[this.id]=true
		init_object(lifeup,this.x,this.y)
		destroy_object(this)
		if time_ticking then
			fruit_count+=1
		end
	end
end

lifeup={
	init=function(this)
		this.spd.y=-0.25
		this.duration=30
		this.flash=0
	end,
	update=function(this)
		this.duration-=1
		if this.duration<=0 then
			destroy_object(this)
		end
	end,
	draw=function(this)
		this.flash+=0.5
		?"1000",this.x-4,this.y-4,7+this.flash%2
	end
}

fake_wall={
	is_fruit=true,
	init=function(this)
		this.solid_obj=true
		this.hitbox=rectangle(0,0,16,16)
	end,
	update=function(this)
		this.hitbox=rectangle(-1,-1,18,18)
		local hit=this.player_here()
		if hit and hit.dash_effect_time>0 then
			hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
			hit.dash_time=-1
			for ox=0,8,8 do
				for oy=0,8,8 do
					this.init_smoke(ox,oy)
				end
			end
			init_fruit(this,4,4)
		end
		this.hitbox=rectangle(0,0,16,16)
	end,
	draw=function(this)
		sspr(0,32,8,16,this.x,this.y)
		sspr(0,32,8,16,this.x+8,this.y,8,16,true,true)
	end
}

function init_fruit(this,ox,oy)
	sfx_timer=20
	sfx"16"
	init_object(fruit,this.x+ox,this.y+oy,26).id=this.id
	destroy_object(this)
end

key={
	update=function(this)
		this.spr=flr(9.5+sin(frames/30))
		if frames==18 then -- if spr==10 and previous spr~=10
			this.flip.x=not this.flip.x
		end
		if this.player_here() then
			sfx"23"
			sfx_timer=10
			destroy_object(this)
			has_key=true
		end
	end
}

chest={
	is_fruit=true,
	init=function(this)
		this.x-=4
		this.start=this.x
		this.timer=20
	end,
	update=function(this)
		if has_key then
			this.timer-=1
			this.x=this.start-1+rnd"3"
			if this.timer<=0 then
				init_fruit(this,0,-4)
			end
		end
	end
}

platform={
	init=function(this)
		this.x-=4
		this.hitbox.w=16
		this.dir=this.spr==11 and -1 or 1
		this.semisolid_obj=true
		
		this.layer=2
	end,
	update=function(this)
		this.spd.x=this.dir*0.65
		-- screenwrap
		if this.x<-16 then
			this.x=lvl_pw
		elseif this.x>lvl_pw then
			this.x=-16
		end
	end,
	draw=function(this)
		spr(11,this.x,this.y-1,2,1)
	end
}

message={
	init=function(this)
		this.text="-- celeste mountain --#this memorial to those#perished on the climb"
		this.hitbox.x+=4
		this.layer=4
	end,
	draw=function(this)
		if this.player_here() then
			for i,s in ipairs(split(this.text,"#")) do
				camera()
				rectfill(7,7*i,120,7*i+6,7)
				?s,64-#s*2,7*i+1,0
				camera(draw_x,draw_y)
			end
		end
	end
}

big_chest={
	init=function(this)
		this.state=max_djump>1 and 2 or 0
		this.hitbox.w=16
	end,
	update=function(this)
		if this.state==0 then
			local hit=this.check(player,0,8)
			if hit and hit.is_solid(0,1) then
				music(-1,500,7)
				sfx"37"
				pause_player=true
				hit.spd=vector(0,0)
				this.state=1
				this.init_smoke()
				this.init_smoke(8)
				this.timer=60
				this.particles={}
			end
		elseif this.state==1 then
			this.timer-=1
			flash_bg=true
			if this.timer<=45 and #this.particles<50 then
				add(this.particles,{
					x=1+rnd"14",
					y=0,
					h=32+rnd"32",
				spd=8+rnd"8"})
			end
			if this.timer<0 then
				this.state=2
				this.particles={}
				flash_bg,bg_col,cloud_col=false,2,14
				init_object(orb,this.x+4,this.y+4,102)
				pause_player=false
			end
		end
	end,
	draw=function(this)
		if this.state==0 then
			draw_obj_sprite(this)
			spr(96,this.x+8,this.y,1,1,true)
		elseif this.state==1 then
			foreach(this.particles,function(p)
				p.y+=p.spd
				line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
			end)
		end
		spr(112,this.x,this.y+8)
		spr(112,this.x+8,this.y+8,1,1,true)
	end
}

orb={
	init=function(this)
		this.spd.y=-4
	end,
	update=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.player_here()
		if this.spd.y==0 and hit then
			music_timer=45
			sfx"51"
			freeze=10
			destroy_object(this)
			max_djump=2
			hit.djump=2
		end
	end,
	draw=function(this)
		draw_obj_sprite(this)
		for i=0,0.875,0.125 do
			circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
		end
	end
}

flag={
	init=function(this)
		this.x+=5
	end,
	update=function(this)
		if not this.show and this.player_here() then
			sfx"55"
			sfx_timer,this.show,time_ticking=30,true,false
		end
	end,
	draw=function(this)
		spr(118+frames/5%3,this.x,this.y)
		if this.show then
			camera()
			rectfill(32,2,96,31,0)
			spr(26,55,6)
			?"x"..two_digit_str(fruit_count),64,9,7
			draw_time(43,16)
			?"deaths:"..two_digit_str(deaths),48,24,7
			camera(draw_x,draw_y)
		end
	end
}

-- [object class]

function init_object(type,x,y,tile)
	-- generate and check berry id
	local id=x..":"..y..":"..lvl_id
	if type.is_fruit and collected[id] then
		return
	end

	local obj={
		type=type,
		collideable=true,
		-- collides=false,
		spr=tile,
		flip=vector(),
		x=x,
		y=y,
		hitbox=rectangle(0,0,8,8),
		spd=vector(0,0),
		rem=vector(0,0),
		layer=0,
		id=id,
	}

	function obj.left() return obj.x+obj.hitbox.x end
	function obj.right() return obj.left()+obj.hitbox.w-1 end
	function obj.top() return obj.y+obj.hitbox.y end
	function obj.bottom() return obj.top()+obj.hitbox.h-1 end

	function obj.is_solid(ox,oy)
		for o in all(objects) do
			if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy) then
				return true
			end
		end
		return oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3) or -- jumpthrough or
		obj.is_flag(ox,oy,0) -- solid terrain
	end

	function obj.is_ice(ox,oy)
		return obj.is_flag(ox,oy,4)
	end

	function obj.is_flag(ox,oy,flag)
		for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
			for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
				if fget(tile_at(i,j),flag) then
					return true
				end
			end
		end
	end

	function obj.objcollide(other,ox,oy)
		return other.collideable and
		other.right()>=obj.left()+ox and
		other.bottom()>=obj.top()+oy and
		other.left()<=obj.right()+ox and
		other.top()<=obj.bottom()+oy
	end

	-- returns first object of type colliding with obj
	function obj.check(type,ox,oy)
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				return other
			end
		end
	end
	
	-- returns all objects of type colliding with obj
	function obj.check_all(type,ox,oy)
		local tbl={}
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				add(tbl,other)
			end
		end
		
		if #tbl>0 then return tbl end
	end

	function obj.player_here()
		return obj.check(player,0,0)
	end

	function obj.move(ox,oy,start)
		for axis in all{"x","y"} do
			obj.rem[axis]+=axis=="x" and ox or oy
			local amt=round(obj.rem[axis])
			obj.rem[axis]-=amt
			local upmoving=axis=="y" and amt<0
			local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
			local movamt
			if obj.collides then
				local step=sign(amt)
				local d=axis=="x" and step or 0
				local p=obj[axis]
				for i=start,abs(amt) do
					if not obj.is_solid(d,step-d) then
						obj[axis]+=step
					else
						obj.spd[axis],obj.rem[axis]=0,0
						break
					end
				end
				movamt=obj[axis]-p -- save how many px moved to use later for solids
			else
				movamt=amt
				if (obj.solid_obj or obj.semisolid_obj) and upmoving and riding then
					movamt+=obj.top()-riding.bottom()-1
					local hamt=round(riding.spd.y+riding.rem.y)
					hamt+=sign(hamt)
					if movamt<hamt then
						riding.spd.y=max(riding.spd.y,0)
					else
						movamt=0
					end
				end
				obj[axis]+=amt
			end
			if (obj.solid_obj or obj.semisolid_obj) and obj.collideable then
				obj.collideable=false
				local hit=obj.player_here()
				if hit and obj.solid_obj then
					hit.move(axis=="x" and (amt>0 and obj.right()+1-hit.left() or amt<0 and obj.left()-hit.right()-1) or 0,
									axis=="y" and (amt>0 and obj.bottom()+1-hit.top() or amt<0 and obj.top()-hit.bottom()-1) or 0,
									1)
					if obj.player_here() then
						kill_player(hit)
					end
				elseif riding then
					riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
				end
				obj.collideable=true
			end
		end
	end

	function obj.init_smoke(ox,oy)
		init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
	end

	add(objects,obj);

	(obj.type.init or stat)(obj)

	return obj
end

function destroy_object(obj)
	del(objects,obj)
end

function move_camera(obj)
	cam_spdx=cam_gain*(4+obj.x-cam_x)
	cam_spdy=cam_gain*(4+obj.y-cam_y)

	cam_x+=cam_spdx
	cam_y+=cam_spdy

	-- clamp camera to level boundaries
	local clamped=mid(cam_x,64,lvl_pw-64)
	if cam_x~=clamped then
		cam_spdx=0
		cam_x=clamped
	end
	clamped=mid(cam_y,64,lvl_ph-64)
	if cam_y~=clamped then
		cam_spdy=0
		cam_y=clamped
	end
end

function draw_object(obj)
	(obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
	spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end
-->8
-- [level loading]

function next_level()
	local next_lvl=lvl_id+1
	shieldcoins = {}
    shieldleftcounter=0
    shieldtopcounter=0 
	-- check for music trigger
	if music_switches[next_lvl] then
		music(music_switches[next_lvl],500,7)
	end

	load_level(next_lvl)
end

function load_level(id)
	has_dashed,has_key= false

	-- remove existing objects
	foreach(objects,destroy_object)

	-- reset camera speed
	cam_spdx,cam_spdy=0,0

	local diff_level=lvl_id~=id

	-- set level index
	lvl_id=id

	-- set level globals
	local tbl=split(levels[lvl_id])
	for i=1,4 do
		_ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
	end
	lvl_title=tbl[5]
	lvl_pw,lvl_ph=lvl_w*8,lvl_h*8

	-- level title setup
	ui_timer=5

	-- reload map
	if diff_level then
		reload()
		-- check for mapdata strings
		if mapdata[lvl_id] then
			replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
		end
	end

	-- entities
	for tx=0,lvl_w-1 do
		for ty=0,lvl_h-1 do
			local tile=tile_at(tx,ty)
			if tiles[tile] then
				init_object(tiles[tile],tx*8,ty*8,tile)
			end
		end
	end
end

-- replace mapdata with hex
function replace_mapdata(x,y,w,h,data)
	for i=1,#data,2 do
		mset(x+i\2%w,y+i\2\w,"0x"..sub(data,i,i+1))
	end
end
-->8
-- [metadata]

--@begin
-- level table
-- "x,y,w,h,title"
levels={
  "0,0,2,2,",
  "-0.0625,1,5.0625,2,"
}

-- mapdata string table
-- assigned levels will load from here instead of the map
mapdata={
  "323232323232323232323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000342222230d0e0f000000000000000000000000000000000000000000000000000031253300000000000072000000730000000000000000000000000000000000000037000000000000000000000000000000000000000000000000000000000000000000001600000000000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000004200000000000000000000000000000000000000222222222222222300000000000000000000000000000000000000000000000025252525252525330000525353535300000000000063000000000000342222222525253232253300000062000000000000000000000000000000000000312525252533000037000000000000000000000000000000000000000000000000242532260000000000000000000000000000000000000000000000000000000031250037000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "252525252600000000000000000000000000000000000000000000000000000000000031323225252525252525252525323233000000000000000000000000000000000000000000000000000000000000252525253300000000000000000000000000000000000000000000000000000000000000000031323232323232323233000000000000000000000000000000000000000000000000000000000000000000252525330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000253233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000000000e0000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000072000000000000000000000000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000000730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000007200000000000000007200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000027000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000024222222222223000000002700000000000000000000000000000000000000000000000000000000002222222222230000000000000000000000000000000000000000000000000000000000000000000031322525252525222222222522222222222222222222222222222222222222222222222222360d0e0f252525252533000000004200000000000000000000000000000000000000000000000000000000000000313232323232323232323232323232323232323232323232323232323232323232323300000000252525252600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000252525253300000052535353530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001600252532330000000062000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000253300000000000062000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000062000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000063000000000034222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000312525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003125000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
}

-- list of music switch triggers
-- assigned levels will start the tracks set here
music_switches={
	[2]=20,
	[3]=30
}

local __init = _init function _init() __init() begin_game() load_level(2) music(-1) max_djump=2 end
--@end

-- tiles stack
-- assigned objects will spawn from tiles set here
tiles={}
foreach(split([[
1,player_spawn
8,key
11,platform
12,platform
18,spring
19,spring
20,chest
22,singlecrystal
23,fall_floor
26,fruit
45,fly_fruit
64,fake_wall
66,shieldcoin
82,shield_corner
83,shield_top
86,message
96,big_chest
98,shield_left
99,shield_target
114,gbubble
115,rbubble
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)

--[[

short on tokens?
everything below this comment
is just for grabbing data
rather than loading it
and can be safely removed!

--]]

-- copy mapdata string to clipboard
function get_mapdata(x,y,w,h)
	local reserve=""
	for i=0,w*h-1 do
		reserve..=num2hex(mget(x+i%w,y+i\w))
	end
	printh(reserve,"@clip")
end

-- convert mapdata to memory data
function num2hex(v)
	return sub(tostr(v,true),5,6)
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700494949494949494949494949
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770222222222222222222222222
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000420000000000000024000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677004200000000000000002400
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000042000000000000000000240
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000420000000000000000000024
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000200000000000000000000002
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000000000000000000000000
555555550000000000000000000000000000000000066000000660004999999449999994499909940300b0b06665666500000000000000000000000070000000
555555550000000000000000000400000000000000655d0000677d00911111199111411991140919003b33006765676500000000007700000770070007000007
550000550000000000000000000950500aaaaaa0065515d00677bbd0911111199111911949400419028888206770677000000000007770700777000000000000
55000055007000700499994000090505a998888a65511105677bb3b5911111199494041900000044089888800700070000000000077777700770000000000000
55000055007000700050050000090505a988888a6511100567bbbb35911111199114094994000000088889800700070000000000077777700000700000000000
55000055067706770005500000095050aaaaaaaa0d5100500d3b3350911111199111911991400499088988800000000000000000077777700000077000000000
55555555567656760050050000040000a980088a00d0050000d33500911111199114111991404119028888200000000000000000070777000007077007000070
55555555566656660005500000000000a988888a0005500000055000499999944999999444004994002882000000000000000000000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37070000000700007707777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
577775570000000000cccc0000cccc0000000000000000000000000000000000cccccccc00066000000000000000000000000000000000000000000000000000
77777777000000000c0000c00c0000c000000000000000000000000000000000c77ccccc00677600000000000000000000000000000000000000000000000000
7777cc7700000000c00cc00cc00cc00c00000000000000000000000000000000c77cc7cc0677e2d0000000000000000000000000000000000000000000000000
777ccccc00000000c0c00c0cc00cc00c00000000000000000000000000000000cccccccc06eee2d0000000000000000000006000000000000000000000000000
77cccccc00000000c0cccc0cc00cc00c00000000000000000002eeeeeeee2000cccccccc0d522d50000000000000000000060600000000000000000000000000
57cc77cc00000000c00cc00cc00cc00c0000000000000000002eeeeeeeeee200cc7ccccc0de55250000000000000000000d00060000000000000000000000000
577c77cc000000000c0000c00c0000c0000000000000000000eeeeeeeeeeee00ccccc7cc00de250000000000000000000d00000c000000000000000000000000
777ccccc0000000000cccc0000cccc00000000000000000000e22222e2e22e00cccccccc000550000000000000000000d000000c000000000000000000000000
777ccccc000000001666d16666656666000000000000000000eeeeeeeeeeee000000000000000000000000000000000c0000000c000600000000000000000000
577ccccc000000006666d56666d1666d000000000000000000e22e2222e22e00000000000000000000000000000000d000000000c060d0000000000000000000
57cc7ccc00000000666d51dddd516ddd000000000000000000eeeeeeeeeeee0000000000000000000000000000000c00000000000d000d000000000000000000
77cccccc0000000066d5111111111111000000000000000000eee222e22eee0000000000000000000000000000000c0000000000000000000000000000000000
777ccccc000000006d51111111111111000000000000000000eeeeeeeeeeee005555555506666600666666006600c00066666600066666006666660066666600
7777cc7700000000dd51111111111111000000000000000000eeeeeeeeeeee00555555556666666066666660660c000066666660666666606666666066666660
77777777000000005111111111111111000000000000000000ee77eee7777e005555555566000660660000006600000066000000660000000066000066000000
57777577000000006d511111111111110000000000000000077777777777777055555555dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
00000000000000006dd11111111cc1110000000000000000007777005000000000000005dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
00aaaaaa0000000066d1111111cccc110000000000000000070000705500000000000055ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
0a9999990000000066d111111cc11cc100000000000000007077000755500000000005550ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
a99aaaaa00000000666111111cc11cc100000000000000007077bb07555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaa00000000151111111cccccc10000000000000000700bbb0755555555555555550000000000000c000000000000000000000000000000c00000000000
a9999999000000006d5111111cccccc10000000000000000700bbb075555555555555555000000000000c00000000000000000000000000000000c0000000000
a99999990000000066d1111111cccc1100000000000000000700007055555555555555550000000000cc0000000000000000000000000000000000c000000000
a99999990000000066d11111111cc1110000000000000000007777005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaa0000000000777700007777000076760000000000004bbb00004b000000400bbb00000000c0000000000000000000000000000000000000c000000000
a49494a10000000007b77770078777700600007000000000004bbbbb004bb000004bbbbb0000000100000000000000000000000000000000000000c00c000000
a494a4a1000000007b777b3778777827700000060000000004200bbb042bbbbb042bbb00000000c0000000000000000000000000000000000000001010c00000
a49444aa000000007bbbb337782882276000000700000000040000000400bbb004000000000001000000000000000000000000000000000000000001000c0000
a49999aa000000007bb3333778822227700000060000000004000000040000000400000000000100000000000000000000000000000000000000000000010000
a4944499000000007b3333b778222287600000070000000042000000420000004200000000000100000000000000000000000000000000000000000000001000
a494a44400000000073b3b7007282870070000600000000040000000400000004000000000000000000000000000000000000000000000000000000000000000
a4949999000000000077770000777700006767000000000040000000400000004000000000010000000000000000000000000000000000000000000000000010
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888777777888eeeeee888eeeeee888eeeeee888eeeeee888eeeeee888eeeeee888888888888888888ff8ff8888228822888222822888888822888888228888
8888778887788ee88eee88ee888ee88ee888ee88ee8e8ee88ee888ee88ee8eeee88888888888888888ff888ff888222222888222822888882282888888222888
888777878778eeee8eee8eeeee8ee8eeeee8ee8eee8e8ee8eee8eeee8eee8eeee88888e88888888888ff888ff888282282888222888888228882888888288888
888777878778eeee8eee8eee888ee8eeee88ee8eee888ee8eee888ee8eee888ee8888eee8888888888ff888ff888222222888888222888228882888822288888
888777878778eeee8eee8eee8eeee8eeeee8ee8eeeee8ee8eeeee8ee8eee8e8ee88888e88888888888ff888ff888822228888228222888882282888222288888
888777888778eee888ee8eee888ee8eee888ee8eeeee8ee8eee888ee8eee888ee888888888888888888ff8ff8888828828888228222888888822888222888888
888777777778eeeeeeee8eeeeeeee8eeeeeeee8eeeeeeee8eeeeeeee8eeeeeeee888888888888888888888888888888888888888888888888888888888888888
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111dd11ddd1dd11ddd1ddd1ddd1ddd1d111ddd1ddd1ddd1ddd1ddd11dd1dd111dd1111111111111111111111111111111111111111111111111111
1111111111111d1111d11d1d11d111d111d11d1d1d1111d1111d1d1d11d111d11d1d1d1d111d1111111111111111111111111111111111111111111111111111
1ddd1ddd11111d1111d11d1d11d111d111d11ddd1d1111d111d11ddd11d111d11d1d1d1d111d1111111111111111111111111111111111111111111111111111
1111111111111d1111d11d1d11d111d111d11d1d1d1111d11d111d1d11d111d11d1d1d1d111d1111111111111111111111111111111111111111111111111111
1111111111111dd11ddd1d1d1ddd11d11ddd1d1d1ddd1ddd1ddd1d1d11d11ddd1dd11d1d11dd1111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1d1d1ddd1ddd11dd11dd1ddd1ddd11111d1d1ddd11111ddd11111dd111111111111111111111111111111111111111111111111111111111
1111111111111d111d1d1d111d1d1d111d1d1d1d1d1111111d1d111d1111111d111111d111111111111111111111111111111111111111111111111111111111
1ddd1ddd11111dd11d1d1dd11dd11d111d1d1dd11dd111111d1d1ddd111111dd111111d111111111111111111111111111111111111111111111111111111111
1111111111111d111ddd1d111d1d1d111d1d1d1d1d1111111ddd1d111111111d111111d111111111111111111111111111111111111111111111111111111111
1111111111111ddd11d11ddd1d1d11dd1dd11d1d1ddd111111d11ddd11d11ddd11d11ddd11111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111dd11ddd1d1d1ddd1ddd11dd11dd1ddd1ddd11111d1d1ddd11111ddd11111dd11111111111111111111111111111111111111111111111111111
1111111111111d1d1d111d1d1d111d1d1d111d1d1d1d1d1111111d1d1d1d11111d1d111111d11111111111111111111111111111111111111111111111111111
1ddd1ddd11111d1d1dd11d1d1dd11dd11d111d1d1dd11dd111111d1d1d1d11111d1d111111d11111111111111111111111111111111111111111111111111111
1111111111111d1d1d111ddd1d111d1d1d111d1d1d1d1d1111111ddd1d1d11111d1d111111d11111111111111111111111111111111111111111111111111111
1111111111111d1d1ddd11d11ddd1d1d11dd1dd11d1d1ddd111111d11ddd11d11ddd11d11ddd1111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111
11661616166616661611166111661166166616611166111188888111111111111111111111111111111111111111111111111111111111111111111111111111
16111616116116111611161616111616116116161611177788888111111111111111111111111111111111111111111111111111111111111111111111111111
16661666116116611611161616111616116116161666111188888111111111111111111111111111111111111111111111111111111111111111111111111111
11161616116116111611161616111616116116161116177788888111111111111111111111111111111111111111111111111111111111111111111111111111
16611616166616661666166611661661166616161661111188888111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117711111111111111111111111111
1eee1e1e1ee111ee1eee1eee11ee1ee1111116161666116616661166166611711616111116161171111111111111111111117771111111111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116161611161111611616161617111616111116161117111111111111111111117777111111111111111111111111
1ee11e1e1e1e1e1111e111e11e1e1e1e111116161661161111611616166117111161111116661117111111111111111111117711111111111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116661611161111611616161617111616117111161117111111111111111111111171111111111111111111111111
1e1111ee1e1e11ee11e11eee1ee11e1e111111611666116611611661161611711616171116661171111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1eee1eee1e1e1eee1ee11111117716161111161611111616111116161771111111111111111111111111111111111111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111117116161777161611111616177716161171111111111111111111111111111111111111111111111111111111111111
11111ee11ee111e11e1e1ee11e1e1111177111611111116111111666111116661177111111111111111111111111111111111111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111117116161777161611711116177711161171111111111111111111111111111111111111111111111111111111111111
11111e1e1eee11e111ee1e1e1e1e1111117716161111161617111666111116661771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1ee11ee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1ee11e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1e1e1eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1e1e1ee111ee1eee1eee11ee1ee1111116661666116616661666166111661611166611711616111116161111161611111616117111111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116161611161111611616161616111611161117111616111116161111161611111616111711111111111111111111
1ee11e1e1e1e1e1111e111e11e1e1e1e111116611661161111611666161616111611166117111161111116661111161611111666111711111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116161611161111611616161616161611161117111616117111161171166611711616111711111111111111111111
1e1111ee1e1e11ee11e11eee1ee11e1e111116161666116611611616161616661666166611711616171116661711166617111616117111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1eee1eee1e1e1eee1ee11111117716161111161611111616111116161111161611111616111116161111161617711111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111117116161777161611111616177716161111161617771616111116161777161611711111111111111111111111111111
11111ee11ee111e11e1e1ee11e1e1111177111611111116111111666111116661111161611111616111116661111166611771111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111117116161777161611711116177711161171166617771666117116161777161611711111111111111111111111111111
11111e1e1eee11e111ee1e1e1e1e1111117716161111161617111666111116661711166611111666171116161111161617711111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1ee11ee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1ee11e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1e1e1eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111dd1d1111dd1ddd1ddd1d1111111ddd1ddd1ddd1d111ddd11dd1111111111111111111111111111111111111111111111111111111111111111
1111111111111d111d111d1d1d1d1d1d1d11111111d11d1d1d1d1d111d111d111111111111111111111111111111111111111111111111111111111111111111
1ddd1ddd11111d111d111d1d1dd11ddd1d11111111d11ddd1dd11d111dd11ddd1111111111111111111111111111111111111111111111111111111111111111
1111111111111d1d1d111d1d1d1d1d1d1d11111111d11d1d1d1d1d111d11111d1111111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1ddd1dd11ddd1d1d1ddd111111d11d1d1ddd1ddd1ddd1dd11111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11661666166616661166166611661111116611661611161116661166166616661661111111771771111111771771111111111111111111111111111111111111
16161616116116111611116116111111161116161611161116111611116116111616177711711171111111711171111111111111111111111111111111111111
16161661116116611611116116661111161116161611161116611611116116611616111117711177111117711177111111111111111111111111111111111111
16161616116116111611116111161171161116161611161116111611116116111616177711711171117111711171111111111111111111111111111111111111
16611666166116661166116116611711116616611666166616661166116116661666111111771771171111771771111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111dd1d1111dd1ddd1ddd1d1111111ddd1ddd1ddd1ddd1ddd11dd1111111111111111111111111111111111111111111111111111111111111111
1111111111111d111d111d1d1d1d1d1d1d11111111d111d11ddd1d111d1d1d111111111111111111111111111111111111111111111111111111111111111111
1ddd1ddd11111d111d111d1d1dd11ddd1d11111111d111d11d1d1dd11dd11ddd1111111111111111111111111111111111111111111111111111111111111111
1111111111111d1d1d111d1d1d1d1d1d1d11111111d111d11d1d1d111d1d111d1111111111111111111111111111111111111111111111111111111111111111
1111111111111ddd1ddd1dd11ddd1d1d1ddd111111d11ddd1d1d1ddd1d1d1dd11111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16661666166616661666166611111661166616111666161611111666166611661666166616661666111111661666161611111666166616661666166611111666
16111616161116111116161111111616161116111616161611111616161116111161161616161161111116111611161611111161116116661611161611111666
16611661166116611161166111111616166116111666166611111661166116661161166616611161111116661661116111111161116116161661166111111616
16111616161116111611161111711616161116111616111611111616161111161161161616161161117111161611161611111161116116161611161611711616
16111616166616661666166617111666166616661616166616661616166616611161161616161161171116611611161616661161166616161666161617111616
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111dd1d1111dd1ddd1ddd1d11111111dd1ddd1ddd1ddd1ddd1ddd11111d1d1ddd1d111d1d1ddd11dd111111111111111111111111111111111111
1111111111111d111d111d1d1d1d1d1d1d1111111d111d1d1ddd1d111d1d1d1d11111d1d1d1d1d111d1d1d111d11111111111111111111111111111111111111
1ddd1ddd11111d111d111d1d1dd11ddd1d1111111d111ddd1d1d1dd11dd11ddd11111d1d1ddd1d111d1d1dd11ddd111111111111111111111111111111111111
1111111111111d1d1d111d1d1d1d1d1d1d1111111d111d1d1d1d1d111d1d1d1d11111ddd1d1d1d111d1d1d11111d111111111111111111111111111111111111
1111111111111ddd1ddd1dd11ddd1d1d1ddd111111dd1d1d1d1d1ddd1d1d1d1d111111d11d1d1ddd11dd1ddd1dd1111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16611666166616161111161611111661166616661616111116161111116616661666111116161111116616661666111116161111116616661666111111661666
16161616161616161111161611111616161616161616111116161111161116161666111116161111161116161666111116161111161116161666111116111616
16161661166616161111116111111616166116661616111116661111161116661616111111611111161116661616111116661111161116661616111116661666
16161616161616661111161611711616161616161666111111161171161116161616111116161171161116161616111111161171161116161616111111161611
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
82888222822882228888828288828228822282228888888888888888888888888888888888888888888882228222822282228882822282288222822288866688
82888828828282888888828288288828828282888888888888888888888888888888888888888888888882888288828882828828828288288282888288888888
82888828828282288888822288288828828282228888888888888888888888888888888888888888888882228222822282228828822288288222822288822288
82888828828282888888888288288828828288828888888888888888888888888888888888888888888888828882888288828828828288288882828888888888
82228222828282228888888282888222822282228888888888888888888888888888888888888888888882228222822288828288822282228882822288822288
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
0000000000000000000000000008080804020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200000000000002020300020202020202000000000000020204020202020202020000000000000004040202020202020200000000000000000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
c7140000370703776037750270702777027750277402771029a0011d0013d0001d001dd0033000320003300000700007000070000700007000070000700007000070000700007000070000700007000070000700
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
