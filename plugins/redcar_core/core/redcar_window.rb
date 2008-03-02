
module Redcar
  class Window < Gtk::Window
    attr_accessor :notebooks, :speedbar, :panes
    
    def show_window
      @show_objects.each(&:show_all)
    end
    
    def hide_window
      @show_objects.each(&:hide_all)
    end
    
    def initialize
      super "Redcar"
      build_widgets
      connect_signals
      
      $ag = Gtk::AccelGroup.new
      self.add_accel_group($ag)
      
      Redcar.keycatcher.enable(self)
    end
    
    def current_pane
      @panes.current_pane
    end
    
    def self.set_context_menu(menu)
      @@context_menu = menu
    end
    
    include Enumerable
    
    def each_pane
      self.panes.each do |pane|
        yield pane
      end
    end
    
    def panes_struct
      @panes
    end
    
    def panes
      if @panes[0].is_a? Redcar::Pane
        @panes
      else
        get_panes(@panes[0])
      end
    end
    
    def get_panes(hash)
      obj = []
      ["left", "right", "top", "bottom"].each do |dir|
        if hash[dir].is_a? Redcar::Pane
          obj << hash[dir]
        else
          if hash[dir]
            obj += get_panes(hash[dir])
          end
        end
      end
      obj
    end
    
    def [](obj)
      case obj.class.to_s
      when "Integer"
        @panes[obj]
      end
    end
    
    def find_tab(name)
      each_pane do |pane|
        pane.each {|tab| return tab if tab.name == name }
      end
    end
    
    def size
      panes.length
    end
    
    def pane_from_tab(tab)
      each_pane do |pane|
        return pane if pane.tabs.include? tab
      end
      nil
    end
    
    def tab_from_document(doc)
      each_pane do |pane|
        tab = pane.tab_from_doc(doc)
        return tab if tab
      end
      nil
    end
    
    def tabs_array
      returning(a=[]) do
        each_pane do |pane| 
          pane.tabs.each do |tab|
            a << tab.name
          end
        end
      end
    end
    
    def all_tabs
      returning(a=[]) do
        each_pane do |pane| 
          pane.tabs.map do |tab|
            a << tab
          end
        end
      end
    end
    
    def focussed_tab
      all_tabs.find {|tab| tab.has_focus?}
    end
    
    def current_pane
      Redcar.current_pane
      #       @notebook_to_pane.values.each do |pane|
      #         if pane.notebook.focus?
      #           return pane
      #         end
      #       end
      #       return @notebook_to_pane.values.first
    end
    
    def find_pane_from_notebook(notebook)
      @notebook_to_pane[notebook]
    end
    
    def replace_in_panes(panes, from, to)
      if panes.is_a? Array
        if from == panes[0]
          panes[0] = to
        elsif panes[0].is_a? Hash and panes[0]["paned"] == from
          panes[0] = to
        else
          replace_in_panes(panes[0], from, to)
        end
      elsif panes.is_a? Hash
        ["left", "right", "top", "bottom"].each do |dir|
          if panes[dir] == from
            panes[dir] = to
          elsif panes[dir].is_a? Hash and panes[dir]["paned"] == from
            panes[dir] = to
          elsif panes[dir].is_a? Hash
            replace_in_panes(panes[dir], from, to)
          end
        end
      end 
    end
    
    # creates the default new notebook that goes into a pane using the 
    # passed in class and block.
    def make_new_notebook
      notebook = Gtk::Notebook.new
      notebook.set_group_id(0)
      @show_objects << notebook
      self.notebooks << notebook
      notebook.signal_connect("button_press_event") do |widget, event|
        Redcar.current_pane = @notebook_to_pane[notebook]
        if event.kind_of? Gdk.EventButton 
          if event.button == 3
            $BUS['/redcar/services/context_menu_popup'].call("Pane", event.button, event.time)
          end
        end
      end
      notebook.signal_connect("page-added") do |nb, widget, _, _|
        pane = @notebook_to_pane[nb]
        tab = (Tab.widget_to_tab||{})[widget]
        tab.label_angle = pane.tab_angle if tab
      end
      return notebook
    end
    
    def split_horizontal(current_notebook)
      paned = current_notebook.parent
      new_notebook = make_new_notebook
      #       return nil unless @paneds.include? paned
      if paned.child1 == current_notebook # (on the left)
        paned.remove(current_notebook)
        hpaned = Gtk::HPaned.new
        hpaned.add(current_notebook)
        hpaned.add(new_notebook)
        paned.add1(hpaned)
      else
        paned.remove(current_notebook)
        hpaned = Gtk::HPaned.new
        hpaned.add(current_notebook)
        hpaned.add(new_notebook)
        paned.add2(hpaned)
      end
      hpaned.show
      hpaned.position = 200
      
      # update Panes tracking information
      currentpane = @notebook_to_pane[current_notebook]
      newpane = Redcar::Pane.new(self, new_notebook)
      replace_in_panes(@panes, 
                       currentpane, 
                       {"split" => "horizontal",
                         "paned" => hpaned,
                         "left" => currentpane,
                         "right" => newpane })
      @notebook_to_pane[new_notebook] = newpane
      Redcar.current_pane = newpane
      return hpaned, newpane
    end
    
    def split_vertical(current_notebook)
      paned = current_notebook.parent
      new_notebook = make_new_notebook
      #       return nil unless @paneds.include? paned
      if paned.child1 == current_notebook # (on the top)
        paned.remove(current_notebook)
        vpaned = Gtk::VPaned.new
        vpaned.add(current_notebook)
        vpaned.add(new_notebook)
        paned.add1(vpaned)
      else
        paned.remove(current_notebook)
        vpaned = Gtk::VPaned.new
        vpaned.add(current_notebook)
        vpaned.add(new_notebook)
        paned.add2(vpaned)
      end
      vpaned.show
      vpaned.position = 200
      
      # update Panes tracking information
      currentpane = @notebook_to_pane[current_notebook]
      newpane = Redcar::Pane.new(self, new_notebook)
      replace_in_panes(@panes, 
                       currentpane, 
                       {"split" => "vertical",
                         "paned" => vpaned,
                         "top" => currentpane,
                         "bottom" => newpane })
      @notebook_to_pane[new_notebook] = newpane
      Redcar.current_pane = newpane
      return vpaned, newpane
    end
    
    def unify(current_notebook)
      Redcar.event :unify, @notebook_to_pane[current_notebook]
      paned = current_notebook.parent
      upper_paned = paned.parent
      return if paned.children.length == 1
      other_notebook = paned.children.find {|p| p != current_notebook}
      if paned.child1 == current_notebook
        single_notebook = current_notebook
        removed_notebook = other_notebook
      else
        single_notebook = other_notebook
        removed_notebook = current_notebook
      end
      #       if single_notebook.is_a? Gtk::HPaned or
      #           single_notebook.is_a? Gtk::VPaned
      #         single_notebook = unify(single_notebook.children.first)
      #       end
      if removed_notebook.is_a? Gtk::HPaned or
          removed_notebook.is_a? Gtk::VPaned
        removed_notebook = unify(removed_notebook.children.first)
      end
      paned.remove(single_notebook)
      paned.remove(removed_notebook)
      single_pane = @notebook_to_pane[single_notebook]
      removed_pane = @notebook_to_pane[removed_notebook]
      removed_pane.tabs.each do |tab|
        removed_pane.migrate_tab(tab, single_pane)
#         removed_notebook.move_document(doc, single_notebook)
#         single_pane.add_tab(removed_pane.tab_from_doc(doc))
      end
      if upper_paned.child1 == paned
        upper_paned.remove(paned)
        upper_paned.add1(single_notebook)
      else
        upper_paned.remove(paned)
        upper_paned.add2(single_notebook)
      end
      paned.hide
      removed_notebook.hide  #TODO: should these be delete or similar?
      if paned.is_a? Gtk::HPaned
        hv = :h
      else
        hv = :v
      end
      replace_in_panes(@panes, 
                       paned,
                       @notebook_to_pane[single_notebook])
      @notebook_to_pane[removed_notebook] = nil
      pane = @notebook_to_pane[single_notebook]
      Redcar.current_pane = pane
      pane.notebook
    end
  end
end