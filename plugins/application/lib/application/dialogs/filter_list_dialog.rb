module Redcar
  # A type of dialog containing a textbox and a list, where the list can be updated
  # based on the contents of the textbox. For example, the Find File dialog box in
  # the Project plugin.
  #
  # Subclasses should implement the 'update_list' method and the 'selected' method.
  class FilterListDialog
    include Redcar::Model
    include Redcar::Observable
    
    def initialize
      self.controller = Redcar.gui.controller_for(self).new(self)
    end
    
    def open
      notify_listeners(:open)
    end
    
    def close
      notify_listeners(:close)
    end
    
    # Called by the controller when the user changes the filter.
    #
    # @param [String] the filter entered by the user
    # @return [Array<String>] the new list to display
    def update_list(filter)
      if filter == ""
        %w(foo bar baz qux quux corge)
      else
        a = []
        5.times {|i| a << filter + " " + i.to_s }
        a
      end
    end
    
    # Called by the controller when the user selects a row in the list.
    #
    # @param [String] the list row text selected by the user
    # @param [Integer] the index of the row in the list selected by the user
    def selected(text, ix)
      puts "Hooray! You selected #{text} at index #{ix}"
    end
  end
end
