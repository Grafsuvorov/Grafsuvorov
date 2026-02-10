FATAL: the database system is resetting
Позиция ошибки: - такая ошибка была

on ssh:notty
There was 1 failed login attempt since the last successful login.
Last login: Wed Nov 19 20:34:16 2025 from rgm-vd-10cf-222.hq.root.ad
[suvorovnd@rgm-s-khgpm01 ~]$ sudo -i -u gpadmin
[gpadmin@rgm-s-khgpm01 ~]$ gpstate -e
20260210:18:17:44:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Starting gpstate with args: -e
20260210:18:17:44:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Gr                                             eenplum Database) 6.26.2_arenadata55 build 2980.gitafb5f3f.el7'
20260210:18:17:44:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL                                              9.4.26 (Greenplum Database 6.26.2_arenadata55 build 2980.gitafb5f3f.el7) on x86_64-unknown-linux-gnu,                                              compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit compiled on Mar 22 2024 17:20:50'
20260210:18:17:44:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Obtaining Segment details from master.                                             ..
20260210:18:17:44:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Gathering data from segments...
20260210:18:17:45:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:---------------------------------------                                             --------------
20260210:18:17:45:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Segment Mirroring Status Report
20260210:18:17:45:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:---------------------------------------                                             --------------
20260210:18:17:45:087499 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-All segments are running normally
[gpadmin@rgm-s-khgpm01 ~]$ gpstate
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Starting gpstate with args:
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Greenplum Database                             ) 6.26.2_arenadata55 build 2980.gitafb5f3f.el7'
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL 9.4.26 (Greenplu                             m Database 6.26.2_arenadata55 build 2980.gitafb5f3f.el7) on x86_64-unknown-linux-gnu, compiled by gcc (GCC) 4.8.5 201                             50623 (Red Hat 4.8.5-44), 64-bit compiled on Mar 22 2024 17:20:50'
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Obtaining Segment details from master...
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Gathering data from segments...
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-Greenplum instance status summary
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Master instance                                                                        = Active
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Master standby                                                                         = rgm-s-khgpm02.hq.root.ad
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Standby master state                                                                   = Standby host passive
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total segment instance count from metadata                                             = 16
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Primary Segment Status
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total primary segments                                                                 = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total primary segment valid (at master)                                                = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total primary segment failures (at master)                                             = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid files missing                                           = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid files found                                             = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid PIDs missing                                            = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid PIDs found                                              = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of /tmp lock files missing                                                = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of /tmp lock files found                                                  = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number postmaster processes missing                                              = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number postmaster processes found                                                = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Mirror Segment Status
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total mirror segments                                                                  = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total mirror segment valid (at master)                                                 = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total mirror segment failures (at master)                                              = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid files missing                                           = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid files found                                             = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid PIDs missing                                            = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of postmaster.pid PIDs found                                              = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of /tmp lock files missing                                                = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number of /tmp lock files found                                                  = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number postmaster processes missing                                              = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number postmaster processes found                                                = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number mirror segments acting as primary segm                             ents   = 0
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-   Total number mirror segments acting as mirror segme                             nts    = 8
20260210:18:18:08:088587 gpstate:rgm-s-khgpm01:gpadmin-[INFO]:-----------------------------------------------------
