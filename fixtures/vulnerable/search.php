<?php
// INTENTIONALLY INSECURE test fixture — do not copy.
$id = $_GET['id'];
$result = $db->query("SELECT * FROM users WHERE id = $id");
