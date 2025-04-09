---
title: "Databases - Permission Security and Access"
description: CIMS Databases – Permission Security and Access Architecture
author: VIA
cims.author: Vinith Ankam
cims.date: 27/03/2025
cims.service: SQL
cims.topic: Security
---
# CIMS Databases - Permission Security and Access Architecture

### **Summary: CIMS Databases – Permission Security and Access Architecture**

1. **User and Team Structure**
        - **DBATeam** (Vinith, Sivagopal) – Handles DBA-specific tasks (permissions, monitoring, backups).
        - **OnsiteTechTeam** – Head of the Databases having sysadm in All environments.
        - **GreenTeam** – Primary data handlers with DML and DDL access for Local Production, staging and production.
        - **BlueTeam & QATeam** – Support roles focused on QA and deployment with limited database access.
        - **Clients** – Limited access via the `cimsint` role.
2. **Environment-Specific Access**
    - **Development (Dev)**:
        - Roles: `cimsddl`, `cimsdml`, `cimsexe`.
        - All users have access for development and testing.
    - **Local/Onsite Staging**:
        - Limited **DDL and DML** for **Green** and Limited **DML** for and **QA Teams**.
        - `cimssupport` manage client-side integrations.
    - **Local/Onsite Production**:
        - **Read-only (`cimsro`)** for most users.
        - DML access is restricted to **Go-Live Support users**.
        - **Adhoc Support** via `cimssupport` for specific teams (Request Based Person).
3. **Role Definitions**
    - **cimsadmin**: Full access, restricted to a few admins.
    - **cimsro**: Read-only for general users.
    - **cimsddl**: Allows schema changes (except **DROP TABLE**).
    - **cimsdml**: Full DML (insert, update, delete) permissions.
    - **cimssupport**: DDL for views/stored procedures with restricted DML.
    - **cimsint**: Integration-specific role with limited insert/update permissions.
    - **cimsapp**: Used by applications for comprehensive DB access.
4. **Key Security Considerations**
    - **Separate User IDs** for different applications and instances to maintain tracking.
    - **RedGate Synchronization** for schema-level changes in production.
    - **Adhoc Access Control** for time-bound support and debugging.
    - **Profiler Access (ALTER TRACE)** for debugging in non-production environments.

This architecture ensures **strict access control**, **auditability**, and **team-specific privileges** across environments while maintaining operational flexibility.

## Team Members

| PersonID | Employee Name  | Team       |
|----------|--------------|-----------|
| 1        | amar.y       | OnsiteTechTeam  |
| 2        | vijay.m      | GreenTeam  |
| 3        | shravan.k    | GreenTeam  |
| 4        | rajanikanth.m| GreenTeam  |
| 5        | sivagopal.k  | DBATeam    |
| 6        | krishna.k    | QATeam     |
| 7        | sreenivas.v  | QATeam     |
| 8        | satwik.b     | QATeam     |
| 9        | sateesh.j    | QATeam     |
| 10       | ajay.m       | QATeam     |
| 11       | eeshwar.b    | OnsiteTechTeam  |
| 12       | guruavinash.g| BlueTeam   |
| 13       | lahari.c     | BlueTeam   |
| 14       | magbul.s     | GreenTeam  |
| 15       | pavan.k      | OnsiteTechTeam  |
| 16       | pavan.pkk    | BlueTeam   |
| 17       | phani.k      | GreenTeam  |
| 18       | ramana.v     | GreenTeam  |
| 19       | ravi.c       | GreenTeam  |
| 20       | rishi.a      | GreenTeam  |
| 21       | srinivas.p   | BlueTeam   |
| 22       | tarak.k      | GreenTeam  |
| 23       | teja.d       | OnsiteTechTeam  |
| 24       | venu.s       | GreenTeam  |
| 25       | venu.l       | BlueTeam   |
| 26       | vinodkumar.n | BlueTeam   |
| 27       | vivek.b      | BlueTeam   |
| 28       | vasanthmasthan.g | BlueTeam   |
| 29       | sanjana.v    | BlueTeam   |
| 30       | charishma.p  | BlueTeam   |
| 31       | vinith.a     | DBATeam    |
| 32       | deepika.m    | BlueTeam   |
| 33       | dushyanth.s  | BlueTeam   |
| 34       | thirumalesh.a| BlueTeam   |
| 35       | mounika.a    | BlueTeam   |
| 36       | rakesh.p     | BlueTeam   |
| 37       | lakshmi.g    | BlueTeam   |
| 38       | harsha.v     | BlueTeam   |
| 39       | amulya.j     | BlueTeam   |
| 40       | raja.c       | BlueTeam   |
| 41       | anusha.s     | BlueTeam   |
| 42       | anvitha.k    | BlueTeam   |
| 43       | lalitha.g    | BlueTeam   |
| 44       | sanyasinaidu.p| BlueTeam   |
| 45       | jahnavi.m    | BlueTeam   |
| 46       | jacob.y      | BlueTeam   |
| 47       | brandon.w    | BlueTeam   |
| 48       | abhishiktha.a| BlueTeam   |
| 49       | nagarjuna.h  | BlueTeam   |
| 50       | yaswanth.k   | BlueTeam   |
| 51       | dheeraj.p    | BlueTeam   |

---

## Environment-Wise Role and Permissions

| Environment       | Role/Permissions | Team | Users | Note |
|------------------|----------------|------|-------|------|
| All             | cimsblankdb (login) |  | All Users | Blank DBs access to users with DB owner permissions |
| All             | "CONNECT ANY DATABASE / VIEW ANY DATABASE SELECT ALL USER SECURABLES / VIEW ANY DEFINITION" |  | All Users | To connect Blank DBs with read-only permissions |
| All             | ALTER TRACE |  | All Users | To connect SQL Profiler. Dev team uses SQL Profiler for debugging |
| All             | SQLAgentOperatorRole |  | All Users | Dev team needs to run SQL jobs |
| Dev             | cimsddl |  | All Users |  |
| Dev             | cimsdml |  | All Users |  |
| Dev             | cimsexe |  | All Users |  |
| Local Staging   | cimsro | Blue |  |  |
| Local Staging   | cimsddl | Green, OnsiteTech |  |  |
| Local Staging   | cimsdml | Green, OnsiteTech, CIMS QA |  |  |
| Local Prod      | cimsro | Blue |  |  |
| Local Prod      | cimsddl |  |  | Should be synced up with RedGate |
| Local Prod      | cimsdml | Green, OnsiteTech |  |  |
| Onsite Staging  | cimsro | Blue |  |  |
| Onsite Staging  | cimsddl | Green, OnsiteTech |  |  |
| Onsite Staging  | cimsdml | Green, OnsiteTech, CIMS QA |  |  |
| Onsite Staging  | cimssupport |  |  |  |
| Onsite Staging  | cimsint | Clients |  |  |
| Onsite Prod     | cimsro | Blue, CIMS QA, CIMS DBA, Clients |  |  |
| Onsite Prod     | cimsddl |  | Go-Live Support users | Should be synced up with RedGate, during go-live will be given access |
| Onsite Prod     | cimsdml |  | Go-Live Support users | Not given access to anyone to make blanket updates |
| Onsite Prod     | cimssupport | Green, OnsiteTech, Adhoc Teams (Request Based) |  | Support for the week gets these privileges |
| Onsite Prod     | cimsint |  | For Client use only |  |

---

## Database Roles and Permissions

| DB Role         | Permissions | Usage/Purpose | Limitations |
|---------------|-------------|---------------|-------------|
| cimsadmin     | All | Superuser access, only used when needed | Separate user IDs with shared passwords |
| cimsro        | Read-Only | Read-only access for all users |  |
| cimsint       | Insert/Update/Execute | Used for integration purposes | Not given in CIMS Prod DB |
| cimsddl       | All DDL (except Drop Table) | Allows users to apply DB changes | Cannot grant CREATE TABLE without DROP permissions |
| cimsdml       | All DML | Allows unrestricted data changes |  |
| cimssupport   | DDL for Views/SPs + DML | Client/testing support | Requires RedGate for schema changes |
| cimsapp       | All DDL/DML & Execute | Used by CIMS applications | Each app/tool has a unique user ID |
| cimsredgate   | All DDL/DML(sysadm) | Used for Jenkins automated Jobs  | NA |
| cimsexe       | Read + Execute | Used for executing procedures | Given only in Dev unless requested |

---

## Notes
- **RedGate**: Schema changes should be done via RedGate.
- **Client Access**: `cimsint` role is meant for client integration only.
- **Support Users**: Weekly rotating team members get `cimssupport` privileges.

---

_Last Updated: 27 March 2025_ VIA
