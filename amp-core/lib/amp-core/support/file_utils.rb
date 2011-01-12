##################################################################
#                  Licensing Information                         #
#                                                                #
#  The following code is licensed, as standalone code, under     #
#  the Ruby License, unless otherwise directed within the code.  #
#                                                                #
#  For information on the license of this code when distributed  #
#  with and used in conjunction with the other modules in the    #
#  Amp project, please see the root-level LICENSE file.          #
#                                                                #
#  © Michael J. Edgar and Ari Brown, 2009-2010                   #
#                                                                #
##################################################################

module Amp
  module Core
    module Support
      # This module is a set of string functions that we use frequently.
      # They used to be monkey-patched onto the String class, but we don't
      # do that anymore.
      module FileUtils
        module_function
        # prevent messing with existing references to FileUtils too much
        extend ::FileUtils

        ##
        # Makes a fancy, quite-random name for a temporary file.
        # Uses the file's name, the current time, the process number, a random number,
        # and the file's extension to make a very random filename.
        #
        # Of course, it could still fail.
        # 
        # @param  [String] basename The base name of the file - just the file's name and extension
        # @return [String] the pseudo-random name of the file to be created
        def amp_make_tmpname(basename)
          case basename
          when Array
            prefix, suffix = *basename
          else
            prefix, suffix = basename, "."+File.extname(basename)
          end
        
          t = Time.now.strftime("%Y%m%d")
          path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}-#{suffix}"
        end

        ##
        # Finds the number of hard links to the file.
        # 
        # @param  [String] file the full path to the file to lookup
        # @return [Integer] the number of hard links to the file
        def amp_num_hardlinks(file)
          lstat = File.lstat(file)
          raise OSError.new("no lstat on windows") if lstat.nil?
          lstat.nlink
        end
        
        ##
        # Forces a rename from file to dst, removing the dst file if it
        # already exists. Avoids system exceptions that might result.
        # 
        # @param [String] file the source file path
        # @param [String] dst the destination file path
        def amp_force_rename(file, dst)
          return unless File.exist? file
          if File.exist? dst
            File.unlink dst
            File.rename file, dst
          else
            File.rename file, dst
          end
        end
        
        ##
        # taken from Rails' ActiveSupport
        # all or nothing babyyyyyyyy
        # use this only for writes, otherwise it's just inefficient
        # fil.e_name is FULL PATH
        class OSError < StandardError; end
        def amp_atomic_write(file_name, mode='w', default_mode=nil, temp_dir=Dir.tmpdir, &block)
          makedirs(File.dirname(file_name))
          touch(file_name) unless File.exists? file_name
          # this is sorta like "checking out" a file
          # but only if we're *just* writing
          new_path = File.join temp_dir, amp_make_tmpname(File.basename(file_name))
          unless mode == 'w'
            copy(file_name, new_path) # allowing us to use mode "a" and others
          end

          
          # open and close it
          val = Kernel::open new_path, mode, &block
          
          begin
            # Get original file permissions
            old_stat = File.stat(file_name)
          rescue Errno::ENOENT
            # No old permissions, write a temp file to determine the defaults
            check_name = ".permissions_check.#{Thread.current.object_id}.#{Process.pid}.#{rand(1000000)}"
            Kernel::open(check_name, "w") { }
            old_stat = stat(check_name)
            unlink(check_name)
            delete(check_name)
          end
          
          # do a chmod, pretty much
          begin
            nlink = amp_num_hardlinks(file_name)
          rescue Errno::ENOENT, OSError
            nlink = 0
            d = File.dirname(file_name)
            File.mkdir_p(d, default_mode) unless File.directory? d
          end
          
          new_mode = default_mode & 0666 if default_mode
          
          # Overwrite original file with temp file
          amp_force_rename(new_path, file_name)
          
          # Set correct permissions on new file
          File.chown(old_stat.uid, old_stat.gid, file_name)
          File.chmod(new_mode || old_stat.mode, file_name)
          
          val
        end
      end
    end
  end
end
