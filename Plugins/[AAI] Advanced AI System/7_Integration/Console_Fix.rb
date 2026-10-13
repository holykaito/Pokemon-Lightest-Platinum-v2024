#===============================================================================
# Advanced AI System - Console Output Fix
# Fixes Windows beep issue when using echoln in debug mode
#===============================================================================

if !defined?(ORIGINAL_ECHOLN_ALIASED)
  ORIGINAL_ECHOLN_ALIASED = true

  module Kernel
    if respond_to?(:echoln)
      alias original_echoln_aai echoln
    end

    def echoln(msg = "")
      return unless $DEBUG

      begin
        clean_msg = msg.to_s.gsub(/[\a\x07]/, '')
        puts clean_msg
        STDOUT.flush
      rescue SystemCallError, IOError, Errno::EINVAL
      end
    end
  end
end
