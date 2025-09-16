
CREATE DATABASE ENVIROMENT;
USE ENVIROMENT;

CREATE TABLE Countries (
    country_id INT AUTO_INCREMENT PRIMARY KEY,
    country_name VARCHAR(100) UNIQUE -- austria
);

CREATE TABLE Pollutants (
    pollutant_id INT AUTO_INCREMENT PRIMARY KEY,
    pollutant_name VARCHAR(100) UNIQUE -- total nitrogen
);

CREATE TABLE Wastes (
    waste_id INT AUTO_INCREMENT PRIMARY KEY,
    classificationCode VARCHAR(10),  --  HW or NONHW
    description VARCHAR(255)         -- Desciption of what the code above means, like Hazordas Waste
);
-- DROP TABLE Sectors
CREATE TABLE Sectors (
    Sector_id INT AUTO_INCREMENT PRIMARY KEY, -- single numbers
    eprtrSectorName VARCHAR(255) -- Energy sector
);

DROP TABLE PollutantTransfers;
DROP TABLE WasteTransfers;

CREATE TABLE WasteTransfers(
    countryName VARCHAR(100), -- name of the country
    reportingYear INT,        -- year of the report
    -- European pollutant release and transfer register
    EPRTRSectorCode DECIMAL(4,1), -- 
    eprtrSectorName VARCHAR(255), -- 
    EPRTRAnnexIMainActivityCode VARCHAR(10), -- 
    EPRTRAnnexIMainActivityLabel TEXT,       -- 
    wasteTreatment VARCHAR(50),              -- type of treatment
    wasteClassification VARCHAR(10),         -- hazardous waste non-hazardous Waste
    transfer DECIMAL(15,2)                   -- amount of waste transferred in weight
);

CREATE TABLE PollutantTransfers (
    countryName VARCHAR(100), -- name of the country
    reportingYear INT,        -- year of the report
    MethodClassification VARCHAR(50), -- How the pollutant amount was measured 
    EPRTRSectorCode DECIMAL(4,1),     -- EPRTR sector code
    eprtrSectorName VARCHAR(255),     -- name of the EPRTR sector
    EPRTRAnnexIMainActivityCode VARCHAR(10), -- main activity code
    EPRTRAnnexIMainActivityLabel TEXT,       -- description of activity
    pollutant VARCHAR(100),          -- pollutant name
    transfer DECIMAL(15,2)           -- amount pollutant transferred
);
																-- THIS IS WHERE WE IMPORT THE DATA 
/*
Original dataset did not have any ID's or primary keys
    i will now add primary keys and foreign keys in order to link the tables
    */
ALTER TABLE WasteTransfers
    ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST,
    -- Foreign keys, linking to other tables
	ADD COLUMN country_id INT,
    ADD COLUMN sector_id INT,
    ADD COLUMN waste_id INT;
																				
ALTER TABLE PollutantTransfers
	ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST,
     -- Foreign keys, linking to other tables
	ADD COLUMN country_id INT,
    ADD COLUMN pollutant_id INT,
    ADD COLUMN sector_id INT;
    
    -- Adding data to the foreign keys
    INSERT IGNORE INTO Countries (country_name)
SELECT DISTINCT TRIM(countryName) FROM WasteTransfers
UNION
SELECT DISTINCT TRIM(countryName) FROM PollutantTransfers;

INSERT IGNORE INTO Sectors (eprtrSectorName)
SELECT DISTINCT TRIM(eprtrSectorName) FROM WasteTransfers
UNION
SELECT DISTINCT TRIM(eprtrSectorName) FROM PollutantTransfers;

INSERT IGNORE INTO Wastes (classificationCode)
SELECT DISTINCT wasteClassification FROM WasteTransfers;

INSERT IGNORE INTO Pollutants (pollutant_name)
SELECT DISTINCT pollutant FROM PollutantTransfers;

 /* 
 Adding contraints, linking with the pirmary key from eg countries to foreign key in the transfers table.
 */
 ALTER TABLE WasteTransfers
  ADD CONSTRAINT fk_waste_country FOREIGN KEY (country_id) REFERENCES Countries(country_id),
  ADD CONSTRAINT fk_waste_sector FOREIGN KEY (sector_id) REFERENCES Sectors(sector_id),
  ADD CONSTRAINT fk_waste_type FOREIGN KEY (waste_id) REFERENCES Wastes(waste_id);

ALTER TABLE PollutantTransfers
  ADD CONSTRAINT fk_poll_country FOREIGN KEY (country_id) REFERENCES Countries(country_id),
  ADD CONSTRAINT fk_poll_sector FOREIGN KEY (sector_id) REFERENCES Sectors(sector_id),
  ADD CONSTRAINT fk_pollutant FOREIGN KEY (pollutant_id) REFERENCES Pollutants(pollutant_id);


-- Adding data for the 4 tables created using the orginal datasets
-- using shortcuts for tables like waste transfers as wt and countries as c
-- im in safe update mode but not null doesnt work, so im using >0 instead

-- this is where im setting the country id
UPDATE WasteTransfers wt
JOIN Countries c ON wt.countryName = c.country_name -- the data we want
SET wt.country_id = c.country_id
WHERE wt.id > 0; -- NOT NULL would not work, im in safe update mode

-- setting sector_id
UPDATE WasteTransfers wt
JOIN Sectors s ON wt.eprtrSectorName = s.eprtrSectorName  -- the data we want
SET wt.sector_id = s.sector_id -- foreign key wt to primary key s
WHERE wt.id > 0;

-- set waste_id
UPDATE WasteTransfers wt
JOIN Wastes w ON wt.wasteClassification = w.classificationCode  -- wastesTrans hw or not, populates it into wastes classcode
SET wt.waste_id = w.waste_id -- foreign key wt to primary key w
WHERE wt.id > 0;

-- PollutantTRANFERS links

-- Set country_id
UPDATE PollutantTransfers pt
JOIN Countries c ON pt.countryName = c.country_name -- the data we want
SET pt.country_id = c.country_id -- foreign key pt --> primary key country
WHERE pt.id > 0;

-- Set sector_id
UPDATE PollutantTransfers pt
JOIN Sectors s ON pt.eprtrSectorName = s.eprtrSectorName -- the data we want from transfers
SET pt.sector_id = s.sector_id -- foreign key pt --> primary key sector
WHERE pt.id > 0;

-- Set pollutant_id
UPDATE PollutantTransfers pt
JOIN Pollutants p ON pt.pollutant = p.pollutant_name
SET pt.pollutant_id = p.pollutant_id  -- foreign key pt --> primary key pollutant
WHERE pt.id > 0;

-- check if it worked, count how many are null, if it returns 0 then that means there are no null
SELECT COUNT(*) FROM WasteTransfers WHERE country_id IS NULL OR sector_id IS NULL OR waste_id IS NULL;

SELECT COUNT(*) FROM PollutantTransfers WHERE country_id IS NULL OR sector_id IS NULL OR pollutant_id IS NULL;

-- Get total waste transferred by country, industry, and year
SELECT c.country_name, s.eprtrSectorName, wt.reportingYear, -- selecting country name from country table, sectorname from sectors table and year from wasteTrans table
SUM(wt.transfer) AS total_waste -- Create new column called total waste
FROM WasteTransfers wt
JOIN Countries c ON wt.country_id = c.country_id
JOIN Sectors s ON wt.sector_id = s.sector_id
GROUP BY c.country_name, s.eprtrSectorName, wt.reportingYear -- Columns
ORDER BY c.country_name, wt.reportingYear; -- order by country in abc and year by 2007, 2008

-- Combine pollution and waste data per country and year to relate pollutant transfer with waste transfer
SELECT
    c.country_name AS Country, -- rename these columns for readability
    pt.reportingYear AS Year,
    SUM(pt.transfer) AS TotalPollutantTransferred, -- create new column called total pollutants
    SUM(wt.transfer) AS TotalWasteTransferred -- creates new column called total waste transferred
FROM PollutantTransfers pt
JOIN Countries c ON pt.country_id = c.country_id -- get all combined data from wt and pt using country
LEFT JOIN WasteTransfers wt ON wt.country_id = pt.country_id AND wt.reportingYear = pt.reportingYear -- join wt and pt by countries and year
GROUP BY c.country_name, pt.reportingYear
ORDER BY c.country_name, pt.reportingYear;
