CREATE TABLE `PROBLEM_ATTEMPT` (
  `userName` varchar(20) NOT NULL,
  `startTime` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `clientID` varchar(50) NOT NULL default 'fill in clientID',
  `userProblem` varchar(50) default NULL COMMENT 'The problem the user asks for when communicating with server. May or may not exist. If it exists, it should match up with a given problem name in STUDENT_DATASET',
  `userSection` varchar(50) NOT NULL DEFAULT 'defaultSection' COMMENT 'The section the user is enrolled in. Must match up with a section in CLASS_INFORMATION.',
  `extra` varchar(50) DEFAULT NULL COMMENT 'Identifiers for multi-user sessions or copied sessions or other such stuff.',
  PRIMARY KEY  (`clientID`),
  KEY `FK_problemstate_classinformation` (`userSection`),
  CONSTRAINT `FK_problemstate_classinformation` FOREIGN KEY (`userSection`) REFERENCES `CLASS_INFORMATION` (`classSection`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='the base table corresponding to problem state at any given t';
