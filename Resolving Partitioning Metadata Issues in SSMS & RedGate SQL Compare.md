## **Title:** Resolving Partitioning Metadata Issues in SSMS & RedGate SQL Compare

## **Objective**
To ensure that partitioning metadata is correctly scripted in SQL Server GUI tools (SSMS and RedGate SQL Compare) to prevent discrepancies when comparing or deploying indexes.

## **Scope**
Applicable to all developers and database administrators using SQL Server Management Studio (SSMS) or RedGate SQL Compare for database scripting and comparison.

---

## **Issue Overview**
- When scripting indexes from SQL Server GUI tools, partitioning metadata (partition scheme and function) may be omitted by default.
- Impact: Scripted indexes lack partitioning clauses, leading to false "matches" during comparisons.

### **Example:**
#### ✅**Expected Index Script:**
```sql
CREATE CLUSTERED INDEX ix_OrderHeaders_Partitioned
ON OrderHeaders (OrderId)
ON ps_Int100K_Primary (OrderId);
```

#### ❌**Observed (Missing Partitioning Metadata):**
```sql
CREATE CLUSTERED INDEX [ix_OrderHeaders_Partitioned]
ON [dbo].[OrderHeaders] ([OrderId] ASC);
```

Without proper settings, the index gets scripted onto the **default filegroup**, leading to inconsistencies.

---

## **Root Cause & Resolution**

### **1. RedGate SQL Data Compare**
**Cause:**
- By default, RedGate SQL Compare ignores **filegroups, partition schemes, and partition functions**.

**Resolution:**
1. Open **RedGate SQL Data Compare**.
2. Go to **Options**.
3. Locate **Ignore filegroups, partition schemes, and partition functions**.
4. **Uncheck** this option to ensure partitioning metadata is retained.
5. Save and re-run the comparison.
   ![image](https://github.com/user-attachments/assets/52761170-de4f-436f-9dff-2671cc189c2b)

### **2. SQL Server Management Studio (SSMS)**
**Cause:**
- SSMS excludes partitioning metadata unless explicitly enabled in settings.

**Resolution:**
1. Open **SSMS**.
2. Navigate to **Tools > Options > SQL Server Object Explorer > Scripting**.
3. Enable the following options:
   - ✅ **Script partition schemes**
   - ✅ **Script data compression options** (Recommended for partitioned tables)
   - ✅ **Enable Script filegroups**
   - ![Screenshot 2025-04-01 005842](https://github.com/user-attachments/assets/3f28be7b-7b92-47e9-b056-a376655da3f2)

4. Click **OK** to save changes.
5. Re-script the index to confirm the partitioning metadata is included.

---

## **Validation & Compliance**
- All team members must update their settings in **SSMS & RedGate**.
- Perform a test scripting of an index to verify that partitioning metadata is retained.
- Notify the DBA team if any issues persist.

---

## **Version History**
| Version | Date       | Author       | Changes           |
|---------|------------|--------------|--------------------|
| 1.0     | 01-04-2025 | VIA  | Initial Draft     |

---

## **Approval**
**Reviewed & Approved By:**  
📌 **[Vinith Ankam]**  
📌 **[Reviewer Name: [NA]]**  
📌 **[01-04-2025]**

