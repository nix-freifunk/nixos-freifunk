{ config, pkgs, lib, ... }:
{

  imports = [
    ./kea-exporter.nix
  ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      # Kea supports control channel, which is a way to receive management
      # commands while the server is running. This is a Unix domain socket that
      # receives commands formatted in JSON, e.g. config-set (which sets new
      # configuration), config-reload (which tells Kea to reload its
      # configuration from file), statistic-get (to retrieve statistics) and many
      # more. For detailed description, see Sections 8.8, 16 and 15.
      control-socket = {
          socket-type = "unix";
          socket-name = "/run/${config.systemd.services.kea-dhcp4-server.serviceConfig.RuntimeDirectory}/kea-dhcp4.socket";
      };
      # Use Memfile lease database backend to store leases in a CSV file.
      lease-database = {
          type = "memfile";
          lfc-interval = 1800;
      };
      dhcp-ddns = {
        enable-updates = false;
      };
      valid-lifetime = 320;
      max-valid-lifetime = 320;
      authoritative = true;
      # Logging configuration starts here. Kea uses different loggers to log various
      # activities. For details (e.g. names of loggers), see Chapter 18.
      loggers = [
        {
          # This section affects kea-dhcp4, which is the base logger for DHCPv4
          # component. It tells DHCPv4 server to write all log messages (on
          # severity INFO or more) to a file.
          name = "kea-dhcp4";
          output_options = [
              {
                  # Specifies the output file. There are several special values
                  # supported:
                  # - stdout (prints on standard output)
                  # - stderr (prints on standard error)
                  # - syslog (logs to syslog)
                  # - syslog:name (logs to syslog using specified name)
                  # Any other value is considered a name of the file
                  output = "stdout";
                  # Shorter log pattern suitable for use with systemd,
                  # avoids redundant information
                  pattern = "%-5p %m\n";
                  # This governs whether the log output is flushed to disk after
                  # every write.
                  # "flush = false;
                  # This specifies the maximum size of the file before it is
                  # rotated.
                  # "maxsize = 1048576;
                  # This specifies the maximum number of rotated files to keep.
                  # "maxver = 8;
              }
          ];
          # This specifies the severity of log messages to keep. Supported values
          # are: FATAL, ERROR, WARN, INFO, DEBUG
          severity = "DEBUG";
          # If DEBUG level is specified, this value is used. 0 is least verbose,
          # 99 is most verbose. Be cautious, Kea can generate lots and lots
          # of logs if told to do so.
          debuglevel = 0;
        }
      ];
    };
  };

}
