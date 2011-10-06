
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

class CbrainTask::CbSerializer < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  after_status_transition 'New', 'Failed Setup Prerequisites', :trigger_cascade_prepreq_failures

  def setup #:nodoc:
    true
  end

  def job_walltime_estimate #:nodoc:
    tot = 0.seconds
    self.enabled_subtasks.each do |otask|
      wt = otask.job_walltime_estimate || 1.minute
      tot += wt
    end
    tot = 1.minute if tot < 1.minute
    tot
  end

  def cluster_commands #:nodoc:
    params   = self.params || {}

    subtasks = self.enabled_subtasks

    commands = [
      "#",
      "# Serial execution of #{subtasks.size} tasks.",
      "#",
      "",
      "# Initialize the built-in bash seconds counter",
      "SECONDS=0"
    ]

    subtasks.each do |otask|
      odir    = otask.full_cluster_workdir
      oscript = otask.qsub_script_basename
      oout    = otask.stdout_cluster_filename
      oerr    = otask.stderr_cluster_filename
      commands += [
        "",
        "# Run task #{otask.fullname}",
        "",
        "if test -d '#{odir}' ; then",
        "  echo Starting script for task '#{otask.fullname}' in blocking mode.",
        "  START=$SECONDS",
        "  cd '#{odir}'",
        "  /bin/bash #{oscript} > '#{oout}' 2> '#{oerr}'",
        "  echo '  -> Finished in' $(( $SECONDS - $START )) \"seconds; cumulative time: $SECONDS seconds.\"",
        "else",
        "  echo Could not find workdir of task '#{otask.fullname}'. Skipping.",
        "fi"
      ]
    end

    commands += [
      "",
      "echo All tasks completed after $SECONDS seconds, at `date`.",
      ""
    ]
    
    commands
  end

  def save_results #:nodoc:
    params   = self.params || {}
    self.addlog("Marking all tasks as ready.")
    self.enabled_subtasks.each do |otask|
      otask.addlog("#{self.fullname} marking me as \"Data Ready\".")
      otask.status_transition!(otask.status, "Data Ready")
      otask.remove_prerequisites_for_post_processing(self)
      otask.save!
      otask.meta[:configure_only] = nil # task becomes normal so it can be manipulated by user
    end
    return true
  end

  # Returns true if all enabled subtasks are
  # either Completed or Failed, which is
  # necessary for restarts.
  def all_subtasks_are?(states = /Completed|Failed|Terminated/) #:nodoc:
    return true if self.enabled_subtasks.all? { |otask| otask.status =~ states }
    self.addlog("Cannot proceed, as subtasks are not in states matching #{states.inspect}.")
    false
  end

  # Since the 'setup' of a serializer does nothing (see above in setup()),
  # a failure to setup is rather unlikely! It if happens, it's some sort of system
  # problem, so we just allow 'recovery' by retrying the whole thing.
  def recover_from_setup_failure #:nodoc:
    true
  end

  def restart_at_setup #:nodoc:
    unless self.all_subtasks_are?(/Completed|Failed|Terminated/)
      self.addlog("This task can only be restarted at Setup if its subtasks are all either Completed, Failed, or Terminated.")
      return false
    end
    self.enabled_subtasks.each do |otask|
      otask.add_prerequisites_for_post_processing(self,'Completed')
      otask.meta[:configure_only] = true
      orig_status = otask.status
      if orig_status =~ /Completed|Terminated/
        otask.restart('Setup')
      else
        otask.status_transition(otask.status, "Failed To Setup") if otask.status =~ /Failed (On Cluster|To PostProcess)/ # resets
        otask.recover
      end
      if orig_status !~ /Prerequisites/ && otask.status !~ /^Recover|Restart/
        self.addlog("Could not recover or restart subtask #{otask.fullname}.")
        return false
      end
      otask.save!
    end
    true
  end

  def restart_at_cluster #:nodoc:
    self.addlog("This task cannot be restarted at the Cluster stage.")
    self.addlog("It can be restarted at Setup if subtasks are all either Completed, Failed or Terminated.")
    self.addlog("It can be restarted at Post Processing if all subtasks are Completed.")
    false
  end

  def restart_at_post_processing #:nodoc:
    unless self.all_subtasks_are?(/Completed/)
      self.addlog("This task can only be restarted at Post Processing if its subtasks are all Completed.")
      return false
    end
    self.enabled_subtasks.each do |otask|
      otask.remove_prerequisites_for_post_processing(self)
      otask.meta[:configure_only] = nil
      otask.restart("PostProcess")
      otask.save!
    end
    self.addlog("This CbSerializer doesn't need to restart its own post processing.")
    self.addlog("Its subtasks, however, were properly notified to do so.")
    false
  end

  # If a serializer fails its setup prerequisites, then we need
  # to mark its subtasks that are New or Configured the same way.
  def trigger_cascade_prepreq_failures(from_state) #:nodoc
    self.enabled_subtasks.select { |t| t.status =~ /New|Configured/ }.each do |otask|
      otask.addlog("#{self.fullname} indicates setup prereq failure.")
      otask.status_transition(otask.status, 'Failed Setup Prerequisites') rescue true
    end
    true
  end

end
