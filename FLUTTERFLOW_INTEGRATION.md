# Buddy App — FlutterFlow Integration Guide

This guide explains how to connect your FlutterFlow mobile app to the Buddy backend API.

---

## Base URL

Once deployed on Replit, your public API base URL will be:

```
https://<your-replit-domain>/api
```

You can find your domain in Replit after deploying (it looks like `buddy-backend.replit.app`).

During development, test with:
```
https://<your-repl-name>.<your-replit-username>.replit.dev/api
```

---

## Endpoints

### 1. Health Check

**Verify the server is running.**

| Field   | Value             |
|---------|-------------------|
| Method  | `GET`             |
| URL     | `/api/healthz`    |

**Response:**
```json
{ "status": "ok" }
```

---

### 2. Upload PDF — `POST /api/upload-pdf`

**Upload a PDF file and extract its text.**

| Field         | Value                    |
|---------------|--------------------------|
| Method        | `POST`                   |
| URL           | `/api/upload-pdf`        |
| Content-Type  | `multipart/form-data`    |
| Field name    | `file`                   |
| Max file size | 20 MB                    |

**Response:**
```json
{
  "message": "PDF uploaded and text extracted successfully.",
  "filename": "biology_notes.pdf",
  "size": 204800,
  "extractedText": "Photosynthesis is the process by which..."
}
```

**Errors:**
```json
{ "error": "Only PDF files are allowed" }
{ "error": "No PDF file uploaded. Use field name: file" }
```

#### FlutterFlow Setup — Upload PDF

1. In FlutterFlow, create an **API Call** (under API Calls > Add API Call):
   - **Name**: `UploadPDF`
   - **Method**: `POST`
   - **URL**: `[Base URL]/upload-pdf`
   - **Body Type**: `Multipart`
   - Add a field named `file` with type `Uploaded File`

2. Create a variable to store the response's `extractedText` field — you'll pass this to the next call.

---

### 3. Generate Quiz — `POST /api/generate-quiz`

**Generate 5 multiple-choice questions from the extracted PDF text.**

| Field         | Value                     |
|---------------|---------------------------|
| Method        | `POST`                    |
| URL           | `/api/generate-quiz`      |
| Content-Type  | `application/json`        |

**Request Body:**
```json
{
  "text": "The full extracted text from the PDF..."
}
```

**Response:**
```json
[
  {
    "question": "What is the main pigment responsible for capturing light energy in photosynthesis?",
    "optionA": "Carotenoid",
    "optionB": "Chlorophyll",
    "optionC": "Anthocyanin",
    "optionD": "Xanthophyll",
    "answer": "B"
  },
  ...4 more questions
]
```

**Errors:**
```json
{ "error": "Request body must include a non-empty 'text' field with the extracted PDF content." }
```

#### FlutterFlow Setup — Generate Quiz

1. Create a new **API Call**:
   - **Name**: `GenerateQuiz`
   - **Method**: `POST`
   - **URL**: `[Base URL]/generate-quiz`
   - **Headers**: `Content-Type: application/json`
   - **Body Type**: `JSON`
   - **Body**:
     ```json
     {
       "text": "[extractedText]"
     }
     ```
   - Replace `[extractedText]` with the variable from the Upload PDF response.

2. Define a **JSON Path** to parse each quiz question from the array response:
   - `$[*].question`
   - `$[*].optionA`
   - `$[*].optionB`
   - `$[*].optionC`
   - `$[*].optionD`
   - `$[*].answer`

---

## Recommended FlutterFlow Workflow

```
User selects PDF file
        ↓
Call POST /upload-pdf (multipart, field: "file")
        ↓
Store extractedText from response
        ↓
Call POST /generate-quiz (body: { text: extractedText })
        ↓
Parse JSON array response
        ↓
Display quiz questions with A/B/C/D options
        ↓
Check user answer against the "answer" field
```

---

## Example Using Dart (Flutter)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://your-domain.replit.app/api';

// Step 1: Upload PDF
Future<String> uploadPdf(List<int> pdfBytes, String filename) async {
  final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-pdf'));
  request.files.add(http.MultipartFile.fromBytes('file', pdfBytes, filename: filename));
  
  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);
  final data = jsonDecode(response.body);
  
  if (response.statusCode == 200) {
    return data['extractedText'];
  } else {
    throw Exception(data['error']);
  }
}

// Step 2: Generate Quiz
Future<List<Map<String, dynamic>>> generateQuiz(String extractedText) async {
  final response = await http.post(
    Uri.parse('$baseUrl/generate-quiz'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'text': extractedText}),
  );

  if (response.statusCode == 200) {
    final List<dynamic> quiz = jsonDecode(response.body);
    return quiz.cast<Map<String, dynamic>>();
  } else {
    final err = jsonDecode(response.body);
    throw Exception(err['error']);
  }
}
```

---

## CORS

The server has CORS enabled for all origins, so FlutterFlow's HTTP requests will work without any extra configuration.

---

## Tips for FlutterFlow

- Store the `extractedText` in an **App State** variable or a **Page State** variable so it persists between the upload step and the quiz generation step.
- Use a **ListView** with a custom list item widget to display each quiz question and its 4 options.
- Compare the user's selected option (`A`, `B`, `C`, or `D`) with the `answer` field to determine if the answer is correct.
- Show a loading spinner while API calls are in progress using FlutterFlow's conditional visibility feature.
