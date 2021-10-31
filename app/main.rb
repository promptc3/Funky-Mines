class Game
  attr_accessor :state, :outputs, :inputs, :grid, :gtk

  # Calls all methods necessary for the app to run successfully.
  def defaults
    add_grid
    state.world ||= add_world
    state.game_win ||= false
    state.game_win_at ||= 0
    state.game_over_at ||= 0
    state.game_over ||= false
    state.click_counter ||= 0
    state.tile_size = 50
    #
    state.cross_laser ||= {path: 'sprites/lasers.png',
                        on: false
                    }
    state.shooter ||= {on: false,
                       path: 'sprites/shooter.png'
                    }
    state.missile ||= {on: false,
                        path: 'sprites/launcher.png'
                    }
    state.bullets ||= []
    state.shooters ||= []
    state.missiles ||= []
    state.launchers ||= []
    state.lasers ||= []
    state.target ||= {x: inputs.mouse.x, y: inputs.mouse.y}
    state.player.x = inputs.mouse.x
    state.player.y = inputs.mouse.y
    state.player_rect = [inputs.mouse.x, inputs.mouse.y, 8, 8]
    state.coords_added ||= []
    state.safe ||= []
    add_bullets
    add_missiles
  end

  def add_bullets
    return if state.shooters.empty?
    state.shooters.each do |s|
        if state.tick_count.mod_zero?(90)
          # since every bullet will have its own trajectory
          outputs.sounds << "sounds/missile.wav"
          theta   = Math.atan2(s[:y] - state.target[:y], s[:x] - state.target[:x])
          state.player_dir += theta.to_degrees
          dx, dy  = theta.to_degrees.vector 10
          state.bullets << {x: s[:x], y: s[:y], w: 20, h: 20, path: 'sprites/bullet.png',
                              origin_x: s[:x], origin_y: s[:y],
                              dx: dx, dy: dy}
        end
    end
  end

  def add_missiles
    return if state.launchers.empty?
    state.launchers.each do |s|
        if state.tick_count.mod_zero?(120)
          state.missiles << {x: s[:x], y: s[:y], w: 20, h: 20, path: 'sprites/bullet_2.png',
                              origin_x: s[:x], origin_y: s[:y]}
          outputs.sounds << "sounds/missile.wav"            
        end
    end
  end

  def update_target
    if state.tick_count.mod_zero?(30)
        state.target = {x: inputs.mouse.x, y: inputs.mouse.y}
    end
  end

  def move_missiles
    return if state.missiles.empty?
    state.missiles.each do |m|
      theta   = Math.atan2(m[:origin_y] - inputs.mouse.y, m[:origin_x] - inputs.mouse.x)
      dx, dy  = theta.to_degrees.vector 5
      m[:x] -= dx
      m[:y] -= dy
    end
  end

  def play_impact_audio
    if !state.game_over && !state.game_win
      outputs.sounds << "sounds/impact_wav.wav"
    end
  end

  def move_bullets
    return if state.bullets.empty?
    state.bullets.each do |b|
        b[:x] -= b[:dx]
        b[:y] -= b[:dy]
    end
  end

  def kill_bullets
    state.bullets.reject! do |b|
      b_point = [b[:x], b[:y]]
      grid_rect = [state.grid_border[:x], state.grid_border[:y], 500, 500]
      if !(b_point.inside_rect?grid_rect)
        play_impact_audio
        true
      end
    end
  end

  def kill_missiles
    return if state.missiles.empty?
    state.missiles.reject! do |m|
      m_point = [m[:x], m[:y]]
      grid_rect = [state.grid_border[:x], state.grid_border[:y], 500, 500]
      if !(m_point.inside_rect?grid_rect)
        play_impact_audio
        true
      end
    end
  end

  def add_world
    # 0 - Ball - 1/121
    # 1 - Enemy - 65 / 121
    # 2 - Safe - 50 / 121
    # 3 - Hint - 5 / 121

    # create array and puts the enemies
    world = Array.new(121, 1)

    # puts the ball
    world[(rand*80).floor + 40] = 0

    # puts the hints
    hint_counter = 5
    while hint_counter > 0
        rand_id = (rand*120).floor
        if (world[rand_id] != 0)
            world[rand_id] = 3
            hint_counter -= 1
        end
    end

    # puts safe spaces
    counter = 50
    while counter > 0
        rand_id = (rand*120).floor
        if ((world[rand_id] != 0) || (world[rand_id] != 3))
            world[rand_id] = 2
            counter -= 1
        end
    end

    return world
  end

  def add_grid
    x, y, h, w = 640 - 500/2, 640 - 500, 500, 500 # calculations done so the grid appears in screen's center
    lines_h = 10
    lines_v = 10
    state.grid_lines ||= draw_grid(x, y, h, w, lines_h, lines_v) 
    state.grid_border ||= {x: x, y: y, w: 500, h: 500}
  end
  # Sets the starting position, ending position, and color for the horizontal separator.
  # The starting and ending positions have the same y values.
  def horizontal_separator y, x, x2
    [x, y, x2, y, 0, 0, 0]
  end

  # Sets the starting position, ending position, and color for the vertical separator.
  # The starting and ending positions have the same x values.
  def vertical_separator x, y, y2
    [x, y, x, y2, 0, 0, 0]
  end
    # Draws the grid by adding in vertical and horizontal separators.
  def draw_grid x, y, h, w, lines_h, lines_v

    # The grid starts off empty.
    grid = []

    # Calculates the placement and adds horizontal lines or separators into the grid.
    curr_y = y # start at the bottom of the box
    dist_y = h / (lines_h + 1) # finds distance to place horizontal lines evenly throughout 500 height of grid
    lines_h.times do
      curr_y += dist_y # increment curr_y by the distance between the horizontal lines
      grid << horizontal_separator(curr_y, x, x + w - 1) # add a separator into the grid
    end

    # Calculates the placement and adds vertical lines or separators into the grid.
    curr_x = x # now start at the left of the box
    dist_x = w / (lines_v + 1) # finds distance to place vertical lines evenly throughout 500 width of grid
    lines_v.times do
      curr_x += dist_x # increment curr_x by the distance between the vertical lines
      grid << vertical_separator(curr_x, y + 1, y  + h) # add separator
    end

    return grid
  end

  def check_click
    if ((inputs.mouse.click) && (inputs.mouse.click.point.inside_rect? state.grid_border))
        # get the mine grid
        coords = get_coords(inputs.mouse.click.point)
        # check if coords are already clicked
        present =  state.coords_added.find_all {|c| c == coords}.first
        outputs.sounds << "sounds/error.wav" if present
        return if present
        # increment click counter
        state.click_counter += 1
        outputs.sounds << "sounds/click.wav"
        state.coords_added << coords
        # add to the world based on click counter
        if state.world[state.click_counter] == 1
            enemy_data = get_rand_enemy coords
            if enemy_data[:id] == 0
              state.shooters << enemy_data[:data]
            elsif enemy_data[:id] == 1
              state.lasers << enemy_data[:data]
            else
              state.launchers << enemy_data[:data]
            end
        elsif state.world[state.click_counter] == 3
          # hint
          state.safe << {x: coords[0], y:coords[1], w: 45, h: 45, path: 'sprites/food/AppleWorm.png'}
        elsif state.world[state.click_counter] == 2
          # safe
          state.safe << {x: coords[0], y:coords[1], w: 45, h: 45, path: 'sprites/food/Apple.png'}
        else
          # win
          state.safe << {x: coords[0], y:coords[1], w: 45, h: 45, path: 'sprites/trophy.png'}
          state.game_win = true
          state.game_win_at = state.tick_count
          if state.game_win_at && state.game_win_at.elapsed_time < (17.seconds)
            outputs.sounds << "sounds/win.wav"
          end
        end
    end
  end

  def get_rand_enemy coords
    # return a new hash with type of enemy
    id = (rand*3).floor
    if id == 0
        # return shooter
        enemy = {x: coords[0], y:coords[1], w: 45, h: 45, path: state.shooter[:path]}
    elsif id == 1
        # return cross laser
        rect_n = [coords[0]+12.5, coords[1]+45, 20, 87]
        rect_s = [coords[0]+12.5, coords[1]-87, 20, 87]
        rect_e = [coords[0]+45, coords[1]+12.5, 87, 20]
        rect_w = [coords[0]-87, coords[1]+12.5, 87, 20]
        enemy = {x: coords[0], y:coords[1], w: 45, h: 45, path: state.cross_laser[:path],
                 rect_n: rect_n, rect_s: rect_s, rect_e: rect_e, rect_w: rect_w, angle: 45}
    else
        # return missile
        enemy = {x: coords[0], y:coords[1], w: 45, h: 45, path: state.missile[:path]}
    end
    return {id: id, data: enemy}
  end

  def get_coords point
    min_diff_x = 500
    min_diff_y = 500
    coords = [0, 0]
    state.grid_lines.each do |l|
        x= l[0]
        diff_x = point.x - x
        if (diff_x < min_diff_x && diff_x > 0)
            coords[0]= x
            min_diff_x = diff_x
        end
    end
    state.grid_lines.each do |l|
        y = l[1]
        diff_y = point.y - y
        if (diff_y < min_diff_y && diff_y > 0)
            coords[1] = y
            min_diff_y = diff_y
        end
    end
    return coords
  end

  def render_game_over
    if state.game_over
      if state.game_over_at > 0 && state.game_over_at.elapsed_time < 2
        outputs.sounds << "sounds/game-over.wav"
      end
      outputs.primitives << { x: Math.sin(rand*180)*2 + 550,
                                  y: 429,
                                  text: "Game Over",
                                  size_enum: 15,
                                  alignment_enum: 1,
                                  r: 259,
                                  g: 7,
                                  b: 79,
                                  a: 255,
                                  font: "fonts/bytes.TTF" }.label!
      outputs.primitives << { x: Math.sin(rand*180)*2 + 550,
                                  y: 380,
                                  text: "Press Space to Replay",
                                  size_enum: 15,
                                  alignment_enum: 1,
                                  r: 259,
                                  g: 7,
                                  b: 79,
                                  a: 255,
                                  font: "fonts/bytes.TTF" }.label!
    end
  end

  def render_game_win
    if state.game_win
      outputs.primitives << { x: Math.sin(rand*180)*2 + 550,
                                  y: 429,
                                  text: "You Win",
                                  size_enum: 15,
                                  alignment_enum: 1,
                                  r: 239,
                                  g: 244,
                                  b: 59,
                                  a: 255,
                                  font: "fonts/bytes.TTF" }.label!
      outputs.primitives << { x: Math.sin(rand*180)*2 + 550,
                                  y: 380,
                                  text: "Press Space to Replay",
                                  size_enum: 15,
                                  alignment_enum: 1,
                                  r: 239,
                                  g: 7,
                                  b: 59,
                                  a: 255,
                                  font: "fonts/bytes.TTF" }.label!
    end
  end


  def render
    # outputs.borders << [state.grid_border[:x], state.grid_border[:y], state.grid_border[:w], state.grid_border[:h], 255, 255, 255]
    # outputs.lines.concat state.grid_lines
    outputs.sprites << [-41, 0, 1366, 720, 'sprites/game-background.png']
    outputs.sprites << [state.safe, state.shooters, state.launchers, state.bullets, state.missiles]
    if state.cross_laser[:on]
      if !state.lasers.empty? && !state.game_over && !state.game_win
        outputs.sounds << "sounds/laser_on.wav"
      end
      state.lasers.each do |l|
        outputs.sprites << l[:rect_n] + ['sprites/laser_beam_v.png'] 
        outputs.sprites << l[:rect_w] + ['sprites/laser_beam_h_1.png'] 
        outputs.sprites << l[:rect_e] + ['sprites/laser_beam_h.png'] 
        outputs.sprites << l[:rect_s] + ['sprites/laser_beam_v_1.png'] 
      end
    end
    outputs.sprites << state.lasers
    outputs.sprites << state.player_rect + ['sprites/spr_orange.png']
    render_game_over
  end

  def shoot_toggle
    if state.tick_count.mod_zero?(90)
        state.shooter[:on] = !state.shooter[:on]
        outputs.sounds << "sounds/bullet.ogg" unless state.bullets.empty? && state.shooter[:on]
    end
    if state.tick_count.mod_zero?(120)
        state.missile[:on] = !state.missile[:on]
    end
    if state.tick_count.mod_zero?(40)
        state.cross_laser[:on] = !state.cross_laser[:on]
    end
  end

  def calc_shooters
    move_bullets
    kill_bullets
  end

  def calc_launchers
    move_missiles
    kill_missiles
  end

  def calc_cross_laser_collision
    return if state.lasers.empty?
    state.lasers.each do |laser|
      if state.cross_laser[:on]
          if state.player_rect.intersect_rect? laser[:rect_n]
            state.game_over_at = state.tick_count
            state.game_over = true
          elsif state.player_rect.intersect_rect? laser[:rect_s]
            state.game_over_at = state.tick_count
            state.game_over = true
          elsif state.player_rect.intersect_rect? laser[:rect_e]
            state.game_over_at = state.tick_count
            state.game_over = true
          elsif state.player_rect.intersect_rect? laser[:rect_w]
            state.game_over_at = state.tick_count
            state.game_over = true
          end
      end
    end
  end

  def calc_edge_collision
    # If the player is about to go out of bounds, put them back in bounds.
    inputs.mouse.x = state.player.x.clamp(390, 883)
    inputs.mouse.y = state.player.y.clamp(140, 633)
  end

  def calc_bullet_collision
    state.bullets.each do  |bullet|
      bullet_rect = [bullet[:x], bullet[:y], bullet[:w], bullet[:h]]
      if state.player_rect.intersect_rect? bullet_rect
          state.game_over_at = state.tick_count
          state.game_over = true
      end
    end
  end

  def calc_missile_collision
    state.missiles.each do  |missile|
      missile_rect = [missile[:x], missile[:y], missile[:w], missile[:h]]
      if state.player_rect.intersect_rect? missile_rect
          state.game_over_at = state.tick_count
          state.game_over = true
      end
    end
  end

  def calc_rotation
    state.launchers.each do |l|
      theta   = Math.atan2(l[:origin_y] - inputs.mouse.y, l[:origin_x] - inputs.mouse.x)
      l[:angle] = theta.to_degrees + 180
    end
    state.shooters.each do |l|
      theta   = Math.atan2(l[:origin_y] - inputs.mouse.y, l[:origin_x] - inputs.mouse.x)
      l[:angle] = theta.to_degrees + 180
    end
  end


  def game_reset
    state.world = nil
    state.click_counter = 0
    state.bullets = []
    state.shooters = []
    state.missiles = []
    state.launchers = []
    state.lasers = []
    state.coords_added = []
    state.safe = []
    state.game_over = false
    state.game_win = false
    state.game_over_at = 0
    state.game_win_at = 0
  end

  def tick
    defaults
    shoot_toggle
    check_click
    update_target 
    calc_shooters
    calc_launchers
    calc_cross_laser_collision
    calc_edge_collision
    calc_bullet_collision
    calc_missile_collision
    calc_rotation
    render
    if state.game_over_at > 0 && state.game_over_at.elapsed_time > 5.seconds
      outputs.sounds << "sounds/replay.wav"
      game_reset
    end
    if state.game_over_at > 0 && inputs.keyboard.space
      outputs.sounds << "sounds/replay.wav"
      game_reset
    end
  end
end

$game = Game.new
def tick args
  args.gtk.hide_cursor
  $game.grid = args.grid
  $game.state = args.state
  $game.outputs = args.outputs
  $game.inputs = args.inputs
  $game.gtk = args.gtk
  $game.tick
  args.outputs.background_color = [34, 33, 33]
  # args.
  args.outputs.primitives << { x: 150,
                               y: 430,
                               text: "Funky Mines",
                               size_enum: 15,
                               alignment_enum: 1,
                               r: 125,
                               g: 0,
                               b: 200,
                               a: 255,
                               font: "fonts/bytes.TTF" }.label!
  args.outputs.primitives << { x: Math.sin(rand*180)*2 + 150,
                               y: 429,
                               text: "Funky Mines",
                               size_enum: 15,
                               alignment_enum: 1,
                               r: 239,
                               g: 247,
                               b: 9,
                               a: Math.sin(rand*180)*150,
                               font: "fonts/bytes.TTF" }.label!
end