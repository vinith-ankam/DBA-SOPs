/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2024/01/02  AY      Added Int100K/Int10K partition function and schema (JLFL-1088)
  2024/11/12  VIA/VS  Initial Revision (HA-4599)
------------------------------------------------------------------------------*/

Go
/*----------------------------------------------------------------------------*/
/* Create Default Partition Functions based upon Integer (RecordId, LPNId etc) fields. The below definitions
   are only for prelim definition only i.e. the boundaries are not accurate and the functions
   would later be modified with accurate boundaries */
/*----------------------------------------------------------------------------*/

/* Setup with initial boundary. Later, these would be extended to have boundary values at every million */
create partition function [pf_Int1M](int)   as range right for values (0, 1000000, 2000000);
create partition function [pf_Int100K](int) as range right for values (0, 100000,  200000);
create partition function [pf_Int10K](int)  as range right for values (0, 10000,   20000);
create partition function [pf_Int1K](int)   as range right for values (0, 100000,  200000); -- to be deprecated

Go

/* This partition scheme is to partition for each 1M records, but all partitions in Primary. This
   scheme does not need to be changed in future, only the function needs to be changed */
create partition scheme [ps_Int1M_Primary]   as partition [pf_Int1M]   ALL TO ([PRIMARY]);
create partition scheme [ps_Int100K_Primary] as partition [pf_Int100K] ALL TO ([PRIMARY]);
create partition scheme [ps_Int10K_Primary]  as partition [pf_Int10K]  ALL TO ([PRIMARY]);
create partition scheme [ps_Int1K_Primary]   as partition [pf_Int1K]   ALL TO ([PRIMARY]);  -- to be deprecated

create partition scheme [ps_Int1M_Secondary]   as partition [pf_Int1M]   ALL TO ([SECONDARY]);
create partition scheme [ps_Int100K_Secondary] as partition [pf_Int100K] ALL TO ([SECONDARY]);
create partition scheme [ps_Int10K_Secondary]  as partition [pf_Int10K]  ALL TO ([SECONDARY]);
create partition scheme [ps_Int1K_Secondary]   as partition [pf_Int1K]   ALL TO ([SECONDARY]);  -- to be deprecated

Go
