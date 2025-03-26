require("dotenv").config(); // Load .env variables

const express = require("express");
const mysql = require("mysql");
const bodyParser = require("body-parser");
const cors = require("cors");

const app = express();
app.use(express.json());
app.use(bodyParser.json());

// MySQL Database Connection
const db = mysql.createConnection({
    host: process.env.DB_ENDPOINT,
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: "my_rds"
});

db.connect(err => {
    if (err) {
        console.error("Database connection failed: ", err);
    } else {
        console.log("Connected to My database");
    }
});

// API Endpoint: Save data
app.post("/save", (req, res) => {
    const { inputname, inputage, inputgender, inputcourse, inputemail } = req.body;
    if (!inputname || !inputage || !inputgender || !inputcourse || !inputemail) {
        return res.status(400).json({ message: "Name and email are required" });
    }

    const query = "INSERT INTO users (inputname, inputage, inputgender, inputcourse, inputemail) VALUES (?, ?, ?, ?, ?)";
    db.query(query, [inputname, inputage, inputgender, inputcourse, inputemail], (err, result) => {
        if (err) {
            console.error("Error inserting data:", err);
            return res.status(500).json({ message: "Database error" });
        }
        res.json({ message: "Data saved successfully" });
    });
});

app.listen(3000, () => {
    console.log("Server running on port 3000");
});
