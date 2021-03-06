# -*- coding: binary -*-

require 'rex/ui/text/output/buffer/stdout'

module Msf
  module Ui
    module Console
      module CommandDispatcher
        #
        # {CommandDispatcher} for commands related to background jobs in Metasploit Framework.
        #
        class Jobs
          include Msf::Ui::Console::CommandDispatcher

          @@jobs_opts = Rex::Parser::Arguments.new(
            "-h" => [ false, "Help banner."                                   ],
            "-k" => [ true,  "Terminate jobs by job ID and/or range."         ],
            "-K" => [ false, "Terminate all running jobs."                    ],
            "-i" => [ true,  "Lists detailed information about a running job."],
            "-l" => [ false, "List all running jobs."                         ],
            "-v" => [ false, "Print more detailed info.  Use with -i and -l"  ]
          )

          def commands
            {
              "jobs"       => "Displays and manages jobs",
              "rename_job" => "Rename a job",
              "kill"       => "Kill a job",
            }
          end

          #
          # Returns the name of the command dispatcher.
          #
          def name
            "Job"
          end

          def cmd_rename_job_help
            print_line "Usage: rename_job [ID] [Name]"
            print_line
            print_line "Example: rename_job 0 \"meterpreter HTTPS special\""
            print_line
            print_line "Rename a job that's currently active."
            print_line "You may use the jobs command to see what jobs are available."
            print_line
          end

          def cmd_rename_job(*args)
            if args.include?('-h') || args.length != 2 || args[0] !~ /^\d+$/
              cmd_rename_job_help
              return false
            end

            job_id   = args[0].to_s
            job_name = args[1].to_s

            unless framework.jobs[job_id]
              print_error("Job #{job_id} does not exist.")
              return false
            end

            # This is not respecting the Protected access control, but this seems to be the only way
            # to rename a job. If you know a more appropriate way, patches accepted.
            framework.jobs[job_id].send(:name=, job_name)
            print_status("Job #{job_id} updated")

            true
          end

          #
          # Tab completion for the rename_job command
          #
          # @param str [String] the string currently being typed before tab was hit
          # @param words [Array<String>] the previously completed words on the command line.  words is always
          # at least 1 when tab completion has reached this stage since the command itself has been completed

          def cmd_rename_job_tabs(str, words)
            return [] if words.length > 1
            framework.jobs.keys
          end

          def cmd_jobs_help
            print_line "Usage: jobs [options]"
            print_line
            print_line "Active job manipulation and interaction."
            print @@jobs_opts.usage
          end

          #
          # Displays and manages running jobs for the active instance of the
          # framework.
          #
          def cmd_jobs(*args)
            # Make the default behavior listing all jobs if there were no options
            # or the only option is the verbose flag
            args.unshift("-l") if args.length == 0 || args == ["-v"]

            verbose = false
            dump_list = false
            dump_info = false
            job_id = nil

            # Parse the command options
            @@jobs_opts.parse(args) do |opt, idx, val|
              case opt
                when "-v"
                  verbose = true
                when "-l"
                  dump_list = true
                # Terminate the supplied job ID(s)
                when "-k"
                  job_list = build_range_array(val)
                  if job_list.blank?
                    print_error("Please specify valid job identifier(s)")
                    return false
                  end
                  print_status("Stopping the following job(s): #{job_list.join(', ')}")
                  job_list.map(&:to_s).each do |job|
                    if framework.jobs.has_key?(job)
                      print_status("Stopping job #{job}")
                      framework.jobs.stop_job(job)
                    else
                      print_error("Invalid job identifier: #{job}")
                    end
                  end
                when "-K"
                  print_line("Stopping all jobs...")
                  framework.jobs.each_key do |i|
                    framework.jobs.stop_job(i)
                  end
                when "-i"
                  # Defer printing anything until the end of option parsing
                  # so we can check for the verbose flag.
                  dump_info = true
                  job_id = val
                when "-h"
                  cmd_jobs_help
                  return false
              end
            end

            if dump_list
              print("\n#{Serializer::ReadableText.dump_jobs(framework, verbose)}\n")
            end
            if dump_info
              if job_id && framework.jobs[job_id.to_s]
                job = framework.jobs[job_id.to_s]
                mod = job.ctx[0]

                output  = '\n'
                output += "Name: #{mod.name}"
                output += ", started at #{job.start_time}" if job.start_time
                print_line(output)

                show_options(mod) if mod.options.has_options?

                if verbose
                  mod_opt = Serializer::ReadableText.dump_advanced_options(mod, '   ')
                  if mod_opt && mod_opt.length > 0
                    print_line("\nModule advanced options:\n\n#{mod_opt}\n")
                  end
                end
              else
                print_line("Invalid Job ID")
              end
            end
          end

          #
          # Tab completion for the jobs command
          #
          # @param str [String] the string currently being typed before tab was hit
          # @param words [Array<String>] the previously completed words on the command line.  words is always
          # at least 1 when tab completion has reached this stage since the command itself has been completed

          def cmd_jobs_tabs(str, words)
            if words.length == 1
              return @@jobs_opts.fmt.keys
            end

            if words.length == 2 && (@@jobs_opts.fmt[words[1]] || [false])[0]
              return framework.jobs.keys
            end

            []
          end

          def cmd_kill_help
            print_line "Usage: kill <job1> [job2 ...]"
            print_line
            print_line "Equivalent to 'jobs -k job1 -k job2 ...'"
            print @@jobs_opts.usage
          end

          def cmd_kill(*args)
            cmd_jobs("-k", *args)
          end

          #
          # Tab completion for the kill command
          #
          # @param str [String] the string currently being typed before tab was hit
          # @param words [Array<String>] the previously completed words on the command line.  words is always
          # at least 1 when tab completion has reached this stage since the command itself has been completed

          def cmd_kill_tabs(str, words)
            return [] if words.length > 1
            framework.jobs.keys
          end
        end
      end
    end
  end
end
