# Midpoint Version 1.0 for Google SketchUp
# Copyright (c) 2010 Rob A. Shinn.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

#   - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
#   - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution. 
#
#   - Neither the name of Rob A. Shinn nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission. 
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE
# IMPLIED WARRANTIES OF MERCHANTABILITY ND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOTLIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
# 
#-----------------------------------------------------------------------------
# Name        :   Midpoint Version 1.0
# Description :   A tool to create a construction point at the midpoint of an
#             :   imaginary line connecting any two arbitrary points.
# Menu Item   :   Draw -> Midpoint
# Usage       :   Select 2 points-
#             :   1. Starting point of the line.
#             :   2. Endpoint of the line.
#             :   A guide point will be drawn at the midpoint of a line 
#             :   connecting the two points.d
# Date        :   12/23/2010
# Type        :   Tool
#-----------------------------------------------------------------------------

class MidpointTool
  PLATFORM = (Object::RUBY_PLATFORM =~ /mswin/i) ? :windows : ((Object::RUBY_PLATFORM =~ /darwin/i) ? :mac : :other)
	def initialize 
		@ip1 = nil
		@ip2 = nil
    @prompt = nil
		@xdown = 0
		@ydown = 0 
	end

	def activate
		Sketchup.active_model.start_operation "Midpoint"
		@ip = Sketchup::InputPoint.new
		@ip1 = Sketchup::InputPoint.new
		@ip2 = Sketchup::InputPoint.new
		@drawn = false
		if Sketchup.active_model.rendering_options["HideConstructionGeometry"] == true 
			Sketchup.active_model.rendering_options["HideConstructionGeometry"] = false 
		end
		self.reset(nil)
	end
  
	def deactivate(view)
		view.invalidate if @drawn
	end
	
	def onCancel(flag, view)
		Sketchup.active_model.commit_operation
		Sketchup.send_action "selectSelectionTool:"
	end
  
	def reset(view)
		@state = 0
		self.set_prompt("Specify first point")
		@ip.clear
		@ip1.clear
		@ip2.clear 
		if view
			view.tooltip = nil
			view.invalidate if @drawn
		end
		@drawn = false
		@dragging = false
	end
	
	def onMouseMove(flags, x, y, view)
		case @state
        when 0
    			@ip.pick view, x, y
		    	if @ip != @ip1
    				view.invalidate if @ip.display? or @ip1.display?
    				@ip1.copy! @ip
    				view.tooltip = @ip1.tooltip
    			end
    			view.tooltip = "First point:"
    
        when 1,2
        		@ip2.pick view, x, y, @ip1
        		view.tooltip = @ip2.tooltip if( @ip2.valid? )
        		view.invalidate
        		if @ip2.valid?
        				length = @ip1.position.distance(@ip2.position)
                Sketchup.vcb_value = length.to_s
            end
			      view.tooltip = "Next point:"
		end
	end

	def onLButtonDown(flags, x, y, view)
		case @state
			when 0
			  @ip1.pick view, x, y
			  if @ip1.valid?
    				@state = 1
            self.set_prompt("Click for next_point")
            Sketchup.vcb_label = "Length"
				    @xdown = x
				    @ydown = y
			  end
			
			when 1,2
			  if @ip2.valid? && @ip2 != @ip1
            self.create_midpoint(@ip1.position, @ip2.position, view) 
				    self.reset(view)
			  end			
		end
		view.lock_inference
	end

	def onLButtonUp(flags, x, y, view)
		if @dragging && @ip2.valid?
			self.create_midpoint(@ip1.position, @ip2.position,view)
			self.reset(view)
		end
	end

	def onKeyDown(key, repeat, flags, view)
		if key == CONSTRAIN_MODIFIER_KEY && repeat == 1
			@shift_down_time = Time.now
			if( view.inference_locked? )
				view.lock_inference
			elsif @state == 0 && @ip1.valid?
				view.lock_inference @ip1
				view.line_width = 3
			elsif @state != 0 && @ip2.valid?
				view.lock_inference @ip2, @ip1
				view.line_width = 3
			end
    end
=begin
    if key == COPY_MODIFIER_KEY
        if @draw_endpoints == true
            @draw_endpoints = false
            puts "Endpoint creation off."
            self.set_prompt(@prompt) 
        else
            @draw_endpoints = true
            puts "Endpoint creation on"
            self.set_prompt(@prompt)
        end
    end
=end
	end

	def onKeyUp(key, repeat, flags, view)
		view.lock_inference if key == CONSTRAIN_MODIFIER_KEY && view.inference_locked? && (Time.now - @shift_down_time) > 0.5
	end

	def onUserText(text, view)
		return if @state == 0
		return if not @ip2.valid?
		begin
			value = text.to_l
		rescue
			puts "Cannot convert #{text} to a Length"
			value = nil
			Sketchup.vcb_value=""
		end
		return if !value
		pt1 = @ip1.position
		vec = @ip2.position - pt1
		return if vec.length == 0.0
		vec.length = value
		pt2 = pt1 + vec
		self.create_geometry(pt1, pt2, view)
		@state = 2
		pt2 = view.screen_coords pt2
		@ip1.pick view,pt2[0],pt2[1]
	end
  
	def draw(view)
	    if @ip1.valid?
			if @ip1.display?
				@ip1.draw(view)
				@drawn = true
			end
			if @ip2.valid?
				@ip2.draw(view) if @ip2.display?
				view.set_color_from_line(@ip1, @ip2)
				self.draw_geometry(@ip1.position, @ip2.position, view)
				@drawn = true
			end
		end
	end
  def set_prompt(text) 
      @prompt = text
      Sketchup.status_text = text
  end
	def create_geometry(p1, p2, view)
		view.model.active_entities.add_cpoint(p1) if @state != 2
		view.model.active_entities.add_cpoint(p2)
	end

  def create_midpoint(p1, p2, view)
      mp = Geom::Point3d.new 
      mp.x = (p1.x + p2.x) / 2.0  
      mp.y = (p1.y + p2.y) / 2.0  
      mp.z = (p1.z + p2.z) / 2.0  
      puts "p1 x=" + p1.x.to_s() + ", y=" + p1.y.to_s() + ", z=" + p1.z.to_s()
      puts "p2 x=" + p2.x.to_s() + ", y=" + p2.y.to_s() + ", z=" + p2.z.to_s()
      puts "mp x=" + mp.x.to_s() + ", y=" + mp.y.to_s() + ", z=" + mp.z.to_s()
      view.model.active_entities.add_cpoint(mp) 
  end

	def draw_geometry(pt1, pt2, view)
		view.draw_line(pt1, pt2)
	end
	
	def MidpointTool.tool
		Sketchup.active_model.select_tool MidpointTool.new
	end
end

if not file_loaded?("midpoint.rb")
   UI.menu("Draw").add_item("Midpoint") {MidpointTool.tool}
end
file_loaded("midpoint.rb")

