require "colorize"

module Efetch
  VERSION = "0.1.0"

  class SystemInfo
    RESET = "\e[0m"

    def self.get_os_name : String
      if File.exists?("/etc/os-release")
        content = File.read("/etc/os-release")
        if match = content.match(/^PRETTY_NAME="?([^"\n]+)"?/)
          return match[1]
        end
        if match = content.match(/^NAME="?([^"\n]+)"?/)
          return match[1]
        end
      end
      `uname -s`.strip
    end

    def self.get_kernel : String
      `uname -r`.strip
    end

    def self.get_uptime : String
      uptime_sec = File.read("/proc/uptime").split[0].to_f.to_i
      hours = uptime_sec // 3600
      minutes = (uptime_sec % 3600) // 60
      "#{hours}h #{minutes}m"
    rescue
      "Unknown"
    end

    def self.get_shell : String
      ENV["SHELL"]?.try(&.split("/").last) || "Unknown"
    end

    def self.get_terminal : String
      if term = ENV["TERM_PROGRAM"]?
        return term
      end

      ppid = Process.ppid
      proc_name = File.read("/proc/#{ppid}/comm").strip rescue nil
      return proc_name if proc_name

      ENV["TERM"]? || "Unknown"
    end

    def self.get_packages : String
      count = 0
      managers = [] of String

      if File.exists?("/usr/bin/dpkg")
        dpkg_count = `dpkg -l 2>/dev/null | grep '^ii' | wc -l`.strip.to_i
        count += dpkg_count
        managers << "dpkg" if dpkg_count > 0
      end

      if File.exists?("/usr/bin/rpm")
        rpm_count = `rpm -qa 2>/dev/null | wc -l`.strip.to_i
        count += rpm_count
        managers << "rpm" if rpm_count > 0
      end

      if File.exists?("/usr/bin/pacman")
        pacman_count = `pacman -Q 2>/dev/null | wc -l`.strip.to_i
        count += pacman_count
        managers << "pacman" if pacman_count > 0
      end

      if count > 0
        "#{count} (#{managers.join(", ")})"
      else
        "Unknown"
      end
    end

    def self.get_memory : String
      meminfo = File.read("/proc/meminfo")
      total = meminfo.match(/MemTotal:\s+(\d+)/).try(&.[1].to_i) || 0
      available = meminfo.match(/MemAvailable:\s+(\d+)/).try(&.[1].to_i) || 0
      used = total - available

      used_mb = used // 1024
      total_mb = total // 1024

      "#{used_mb}MiB / #{total_mb}MiB"
    rescue
      "Unknown"
    end

    def self.get_cpu : String
      cpuinfo = File.read("/proc/cpuinfo")
      if match = cpuinfo.match(/model name\s+:\s+(.+)/)
        cpu_name = match[1].strip
        cpu_name = cpu_name.gsub(/\(R\)|\(TM\)/, "").gsub(/\s+/, " ").strip
        return cpu_name
      end
      "Unknown"
    rescue
      "Unknown"
    end

    def self.get_gpu : String
      gpu_info = `lspci 2>/dev/null | grep -i 'vga\\|3d\\|display'`.strip
      return "Unknown" if gpu_info.empty?

      if match = gpu_info.lines.first?.try(&.match(/:\s+(.+)/))
        gpu_name = match[1]
        gpu_name = gpu_name.gsub(/VGA compatible controller:\s*/, "")
        gpu_name = gpu_name.gsub(/3D controller:\s*/, "")
        return gpu_name
      end

      gpu_info.lines.first? || "Unknown"
    end

    def self.get_desktop_environment : String
      ENV["XDG_CURRENT_DESKTOP"]? ||
        ENV["DESKTOP_SESSION"]? ||
        ENV["XDG_SESSION_DESKTOP"]? ||
        "TTY"
    end

    def self.get_hostname : String
      `hostname`.strip
    end

    def self.get_username : String
      ENV["USER"]? || ENV["USERNAME"]? || "Unknown"
    end
  end

  class Display
    COLORS = {
      red:     "\e[31m",
      green:   "\e[32m",
      yellow:  "\e[33m",
      blue:    "\e[34m",
      magenta: "\e[35m",
      cyan:    "\e[36m",
      white:   "\e[37m",

      bright_red:     "\e[91m",
      bright_green:   "\e[92m",
      bright_yellow:  "\e[93m",
      bright_blue:    "\e[94m",
      bright_magenta: "\e[95m",
      bright_cyan:    "\e[96m",
      bright_white:   "\e[97m",

      bold:  "\e[1m",
      reset: "\e[0m",
    }

    def self.logo : Array(String)
      [
        "#{COLORS[:bright_cyan]}        ___       ",
        "#{COLORS[:bright_cyan]}       /\\  \\      ",
        "#{COLORS[:bright_cyan]}      /::\\  \\     ",
        "#{COLORS[:bright_cyan]}     /:/\\:\\  \\    ",
        "#{COLORS[:cyan]}    /::\\~\\:\\  \\   ",
        "#{COLORS[:cyan]}   /:/\\:\\ \\:\\__\\  ",
        "#{COLORS[:cyan]}   \\:\\~\\:\\ \\/__/  ",
        "#{COLORS[:blue]}    \\:\\ \\:\\__\\    ",
        "#{COLORS[:blue]}     \\:\\ \\/__/    ",
        "#{COLORS[:blue]}      \\:\\__\\      ",
        "#{COLORS[:bright_blue]}       \\/__/      ",
      ]
    end

    def self.color_blocks : String
      blocks = String.build do |str|
        str << COLORS[:reset]
        [40, 41, 42, 43, 44, 45, 46, 47].each do |code|
          str << "\e[#{code}m   "
        end
        str << COLORS[:reset]
      end
      blocks
    end

    def self.info_line(
      icon : String,
      label : String,
      value : String,
      color : Symbol,
    ) : String
      c = COLORS[color]
      reset = COLORS[:reset]
      "#{c}#{COLORS[:bold]}#{label}#{reset}: #{value}"
    end

    def self.render(anon : Bool = false)
      logo_lines = logo

      if anon
        username = "anon"
        hostname = "anon"
      else
        username = SystemInfo.get_username
        hostname = SystemInfo.get_hostname
      end

      info_lines = [
        "",
        "#{COLORS[:bright_cyan]}#{COLORS[:bold]}#{username}" +
        "#{COLORS[:reset]}@#{COLORS[:bright_cyan]}#{COLORS[:bold]}#{hostname}",
        COLORS[:bright_cyan] + "─" * (username.size + hostname.size + 1) + COLORS[:reset],
        info_line("", "OS", SystemInfo.get_os_name, :bright_cyan),
        info_line("", "Kernel", SystemInfo.get_kernel, :bright_red),
        info_line("", "Uptime", SystemInfo.get_uptime, :bright_yellow),
        info_line("", "Packages", SystemInfo.get_packages, :bright_yellow),
        info_line("", "Shell", SystemInfo.get_shell, :bright_yellow),
        info_line("", "Terminal", SystemInfo.get_terminal, :bright_yellow),
        info_line("", "DE", SystemInfo.get_desktop_environment, :bright_blue),
        info_line("", "CPU", SystemInfo.get_cpu, :bright_blue),
        info_line("", "GPU", SystemInfo.get_gpu, :bright_blue),
        info_line("", "Memory", SystemInfo.get_memory, :bright_blue),
        "",
        color_blocks,
        "",
      ]

      max_logo_lines = logo_lines.size
      max_info_lines = info_lines.size
      max_lines = Math.max(max_logo_lines, max_info_lines)
      logo_width = 18
      padding = " " * 4

      puts ""
      max_lines.times do |i|
        logo_part = if i < logo_lines.size
                      logo_lines[i]
                    else
                      " " * logo_width
                    end

        info_part = if i < info_lines.size
                      info_lines[i]
                    else
                      ""
                    end

        puts "#{logo_part}#{COLORS[:reset]}#{padding}#{info_part}#{COLORS[:reset]}"
      end
      puts ""
    end
  end

  def self.run(anon : Bool = false)
    Display.render(anon)
  end
end

anon_mode = false

if ARGV.includes?("--anon")
  anon_mode = true
end

Efetch.run(anon_mode)
