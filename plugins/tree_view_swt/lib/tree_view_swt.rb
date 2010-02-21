
module Redcar
  class TreeViewSWT
    attr_reader :viewer
    
    def initialize(composite, model)
      @composite, @model = composite, model
      @viewer = JFace::Viewers::TreeViewer.new(@composite, Swt::SWT::VIRTUAL)
      @viewer.set_content_provider(TreeMirrorContentProvider.new)
      @viewer.set_input(@model.tree_mirror)
      @viewer.set_label_provider(TreeMirrorLabelProvider.new)
      
      if @model.tree_controller
        @viewer.add_tree_listener(@viewer.getControl, TreeListener.new)
        @viewer.add_open_listener(OpenListener.new(@model.tree_controller))
      end
      
      @model.add_listener(:refresh) do
        s = Time.now
        begin
          @viewer.refresh
        rescue => e
          # Don't know why the @viewer sometimes throws these:
          # "undefined method `getParent' for #<Redcar::TreeViewSWT::TreeMirrorContentProvider:0x44655c8c> (NoMethodError)"
          # It looks like it is expecting a ILazyTreeViewContentProvider, because getParent
          # is in the API for that.
          puts e.message
          puts e.backtrace
        end
        puts "tree refresh took #{Time.now - s} seconds"
      end
    end
    
    def control
      @viewer.getControl
    end
    
    def close
      @viewer.getControl.dispose
    end
    
    class TreeListener
      def tree_collapsed(e)
        p [:collapsed, e]
      end
      
      def tree_expanded(e)
        p [:expanded, e]
      end
    end
    
    class SelectionListener
      def widget_default_selected(e)
        p [:def_selected, e]
      end
      
      def widget_selected(e)
        p [:selected, e]
      end
    end
    
    class DoubleClickListener
      def double_click(e)
        p [:double_click, e]
      end
    end
    
    class OpenListener
      def initialize(controller)
        @controller = controller
      end
      
      def open(e)
        @controller.activated(e.getSelection.toArray.to_a.first)
      end
    end
    
    class TreeMirrorContentProvider
      include JFace::Viewers::ITreeContentProvider

      def input_changed(viewer, _, tree_mirror)
        @viewer, @tree_mirror = viewer, tree_mirror
      end

      def get_elements(tree_mirror)
        tree_mirror.top.to_java
      end

      def has_children(tree_node)
        tree_node.children.any?
      end

      def get_children(tree_node)
        tree_node.children.to_java
      end

      def dispose
      end
    end

    class TreeMirrorLabelProvider
      include JFace::Viewers::ILabelProvider

      def add_listener(*_)
      end

      def remove_listener(*_)
      end

      def get_text(tree_node)
        tree_node.text
      end

      def get_image(tree_node)
        case tree_node.icon
        when :directory
          dir_image
        when :file
          program = org::eclipse::swt::program::Program.findProgram File.extname(tree_node.text)
          if !program
            file_image
          else
            org::eclipse::swt::graphics::Image.new(tree_node.display, program.image_data)
          end
        end
      end

      def dispose
      end
      
      private
      
      def dir_image
        @dir_image ||= begin
          path = File.join(Redcar.root, %w(plugins application icons darwin-folder.png))
          Swt::Graphics::Image.new(ApplicationSWT.display, path)
        end
      end
      
      def file_image
        @file_image ||= begin
          path = File.join(Redcar.root, %w(plugins application icons darwin-file.png))
          Swt::Graphics::Image.new(ApplicationSWT.display, path)
        end
      end
    end
  end
end
