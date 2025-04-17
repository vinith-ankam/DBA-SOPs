/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2024/12/24  VIA     ps_DateTimeMonthly_Secondary and ps_DateMonthly_Secondary schema uncommented as SECONDARY Filegroup implemented (CIMSV3-4132)
  2024/12/13  VIA     ps_DateMonthly_Secondary Scheme Temp fix as Build failing because we are not yet created Secondary Filegroup in Blank DB filegroup Creation (HA-4724)
  2024/10/22  VS      ps_DateMonthly schema renamed as ps_DateMonthlyAnnualDB parition schema (HA-4616)
  2024/10/17  AY      Added ps_DateMonthlyPrimary and revised default functions (HA-4580)
  2024/06/19  MS      Initial Revision (HA-4071)
------------------------------------------------------------------------------*/

Go

/*----------------------------------------------------------------------------*/
/* Create Default Partition Functions based upon date and date time fields. The below definitions
   are only for prelim definition only i.e. the boundaries are not accurate and the functions
   would later be modified with accurate boundaries */
/*----------------------------------------------------------------------------*/

/* Date/DateTime functions with a monthly boundary. Later, these would be extended to have
   boundary values for each month until the end of the current year */
create partition function [pf_DateTimeMonthly](datetime) as range right for values ('2020-01-01', '2021-01-01');
create partition function [pf_DateMonthly](date) as range right for values ('2020-01-01', '2021-01-01');

/*  Date/DateTime functions with quarterly boundary - FOR FUTURE USE - partition schema undefined */
create partition function [pf_DateTimeQuarterly](datetime) as range right for values ('2020-01-01', '2021-01-01');
create partition function [pf_DateQuarterly](date) as range right for values ('2020-01-01', '2021-01-01');

/*  Date/DateTime functions with yearly boundary - FOR FUTURE USE - partition schema undefined */
create partition function [pf_DateTimeYearly](datetime) as range right for values ('2020-01-01', '2021-01-01');
create partition function [pf_DateYearly](date) as range right for values ('2020-01-01', '2021-01-01');

Go

/*----------------------------------------------------------------------------*/
/* The partition schema defines where (which file group) the partitions would reside.
   We have two models as of now
   a. In some cases we would have a yearly DB like CIMSDEProd_2021, CIMSDEProd_2022... in which case
      the partition schema would map the partitions to the appropriate annual DB.
   b. In some cases we would have the partitions in the Primary DB itself
*/
/*----------------------------------------------------------------------------*/

/* Create Default Partition scheme. This is only a prelim definition and the functions
   and these schemas would be extended later */
create partition scheme [ps_DateTimeMonthly_AnnualDB] as partition [pf_DateTimeMonthly] to ([PRIMARY], [PRIMARY], [PRIMARY]);
create partition scheme [ps_DateMonthly_AnnualDB]     as partition [pf_DateMonthly] to ([PRIMARY], [PRIMARY], [PRIMARY]);
create partition scheme [ps_DateQuarterly_AnnualDB]   as partition [pf_DateQuarterly] to ([PRIMARY], [PRIMARY], [PRIMARY]);
create partition scheme [ps_DateYearly_AnnualDB]      as partition [pf_DateYearly] to ([PRIMARY], [PRIMARY], [PRIMARY]);

/* These partition schema is to partition the data and/or index by Month/Quarter/Year to
   the PRIMARY file group only. This is typically used when the table is not partitioned,
   but the index itself is. These schema's do not need to be extended later as all current
   and new/future partitions would still be in Primary only */
create partition scheme [ps_DateTimeMonthly_Primary] as partition [pf_DateTimeMonthly] ALL to ([PRIMARY]);
create partition scheme [ps_DateMonthly_Primary]     as partition [pf_DateMonthly] ALL to ([PRIMARY]);
create partition scheme [ps_DateQuarterly_Primary]   as partition [pf_DateQuarterly] to ([PRIMARY], [PRIMARY], [PRIMARY]);
create partition scheme [ps_DateYearly_Primary]      as partition [pf_DateYearly] to ([PRIMARY], [PRIMARY], [PRIMARY]);

/* These schemas would be to partition the tables/indices in the secondary file group */
create partition scheme [ps_DateTimeMonthly_Secondary] as partition [pf_DateTimeMonthly] ALL to ([SECONDARY]);
create partition scheme [ps_DateMonthly_Secondary]     as partition [pf_DateMonthly] ALL to ([SECONDARY]);

Go
