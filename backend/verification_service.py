"""
AI Document Verification System for Pharmacy License Validation.

Performs OCR (with fallback simulation), field extraction, validation,
authenticity checks, and confidence scoring.
"""

import re
import json
import os
from datetime import datetime, date
from typing import Dict, List, Optional, Tuple

# Try to import OCR and PDF libraries; gracefully fall back if unavailable
try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

try:
    import pytesseract
    TESSERACT_AVAILABLE = True
    # Priority 1: System PATH (standard for winget/manual installs)
    # Priority 2: Common Windows install path
    tess_path = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
    if os.path.exists(tess_path):
        pytesseract.pytesseract.tesseract_cmd = tess_path
    else:
        # Check if 'tesseract' is in PATH by trying to run it
        import subprocess
        try:
            subprocess.run(["tesseract", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            pytesseract.pytesseract.tesseract_cmd = "tesseract"
        except (subprocess.CalledProcessError, FileNotFoundError):
            TESSERACT_AVAILABLE = False
except ImportError:
    TESSERACT_AVAILABLE = False

try:
    import fitz  # PyMuPDF
    FITZ_AVAILABLE = True
except ImportError:
    FITZ_AVAILABLE = False


class LicenseVerifier:
    """AI-powered pharmacy license document verifier."""

    # --- Known license number patterns (regex) ---
    LICENSE_PATTERNS = [
        r"[A-Z]{2,4}[-/]?\d{4,10}",          # e.g. PH-12345, DL/2024/12345
        r"\d{2,4}[-/][A-Z]{1,4}[-/]\d{3,8}",  # e.g. 21/B/12345
        r"[A-Z]{2,4}[-/][A-Z]{2,4}[-/]\d{4,10}", # e.g. KA-BNG-123456
        r"[A-Z]\d{5,12}",                      # e.g. P123456789
        r"\d{6,15}",                            # pure numeric
    ]

    # --- Date patterns ---
    DATE_PATTERNS = [
        r"\d{1,2}[/-]\d{1,2}[/-]\d{4}",   # DD/MM/YYYY or D/M/YYYY
        r"\d{4}[/-]\d{1,2}[/-]\d{1,2}",   # YYYY-MM-DD or YYYY-M-D
        r"\d{1,2}[/-]\d{4}",            # MM/YYYY or M/YYYY
        r"\d{1,2}\s\w+\s\d{4}",         # 12 January 2025
        r"\w+\s\d{1,2},?\s\d{4}",     # January 12, 2025
    ]

    # --- Keywords that signal specific fields ---
    FIELD_KEYWORDS = {
        "pharmacy_name": [
            "pharmacy name", "name of pharmacy", "establishment name",
            "business name", "store name", "registered name",
            "pharmacy", "drug store", "medical store"
        ],
        "license_number": [
            "license no", "licence no", "license number", "licence number",
            "registration no", "reg no", "permit no", "dl no",
            "drug license", "certificate no", "license #"
        ],
        "issue_date": [
            "date of issue", "issued on", "issue date", "valid from",
            "grant date", "date of grant", "effective date", "from"
        ],
        "expiry_date": [
            "valid till", "valid until", "expiry date", "expiration date",
            "valid upto", "valid up to", "expires on", "date of expiry", "to"
        ],
        "authority": [
            "issued by", "issuing authority", "authority", "department",
            "drug controller", "food and drug", "state pharmacy council",
            "central drug", "licensing authority", "competent authority"
        ],
        "non_license_titles": [
            "letter of recommendation", "lor", "noc", "no objection certificate",
            "certificate of participation", "internship certificate",
            "mark sheet", "transcript", "resume", "curriculum vitae", "cv",
            "experience letter", "relieving letter"
        ]
    }

    def __init__(self):
        self.issues: List[str] = []
        self.extracted_data: Dict[str, str] = {
            "pharmacy_name": "",
            "license_number": "",
            "issue_date": "",
            "expiry_date": "",
            "authority": ""
        }

    def verify(self, file_path: str, filename: str, file_size: int) -> Dict:
        """
        Main verification pipeline.
        Returns the structured JSON result.
        """
        self.issues = []
        self.extracted_data = {
            "pharmacy_name": "",
            "license_number": "",
            "issue_date": "",
            "expiry_date": "",
            "authority": ""
        }

        # Step 1: Extract text
        raw_text = self._extract_text(file_path, filename)

        # Step 2: Detect required fields
        if raw_text:
            self._detect_fields(raw_text)

        # Step 3: Validate fields
        self._validate_fields()

        # Step 4: Authenticity checks
        self._check_authenticity(file_path, file_size, filename)

        # Step 5: Calculate confidence score
        score = self._calculate_score(raw_text, file_size, filename)
        print(f"[AI] Calculated Score: {score}")

        # Step 6: Final decision
        status = self._make_decision(score)
        print(f"[AI] Final Decision: {status}")

        return {
            "status": status,
            "confidence_score": score,
            "issues": self.issues,
            "extracted_data": self.extracted_data
        }

    # =========================================================================
    # STEP 1: Text Extraction (OCR or simulation)
    # =========================================================================
    def _extract_text(self, file_path: str, filename: str) -> str:
        """Extract text from a document using OCR or simulation."""
        ext = os.path.splitext(filename)[1].lower()

        # Try real OCR for images
        if ext in [".jpg", ".jpeg", ".png"] and PIL_AVAILABLE and TESSERACT_AVAILABLE:
            try:
                image = Image.open(file_path)
                text = pytesseract.image_to_string(image)
                if text.strip():
                    print(f"[AI] OCR extracted {len(text)} characters from image.")
                    return text
            except Exception as e:
                print(f"[AI] OCR failed: {e}. Falling back to simulation.")

        # Use PyMuPDF for PDFs if available
        if ext == ".pdf" and FITZ_AVAILABLE:
            try:
                doc = fitz.open(file_path)
                text = ""
                for page in doc:
                    text += page.get_text()
                doc.close()
                if text.strip():
                    print(f"[AI] PyMuPDF extracted {len(text)} characters from PDF.")
                    return text
                else:
                    print("[AI] PyMuPDF found no text in PDF (possible scan).")
            except Exception as e:
                print(f"[AI] PyMuPDF failed: {e}")

        return self._simulate_ocr(file_path, filename)

    def _simulate_ocr(self, file_path: str, filename: str) -> str:
        """
        Simulates OCR by reading raw bytes and performing heuristic
        text extraction. For PDFs, searches for embedded text strings.
        For images, uses file metadata as clues.
        """
        text_fragments = []

        try:
            with open(file_path, "rb") as f:
                raw = f.read()

            # --- Binary Safety Check ---
            # If the file contains many null bytes or non-printable chars, it's a binary image
            # simulated OCR on binary images produces garbage
            if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                # Check for binary signatures or high density of non-ASCII
                non_ascii = sum(1 for b in raw[:1000] if b > 127 or b < 9)
                if non_ascii > 100:
                    print(f"[AI] Binary safety guard: image file detected in simulation. Aborting extraction.")
                    return ""

            # Efficiently extract printable ASCII strings
            printable = set(range(32, 127)) | {10, 13}
            # Use chunks or regex for performance
            # Simple list-based construction to avoid O(N^2) string +=
            chars = []
            for byte in raw:
                if byte in printable:
                    chars.append(chr(byte))
                else:
                    if len(chars) > 4:
                        text_fragments.append("".join(chars).strip())
                    chars = []
            if chars:
                text_fragments.append("".join(chars).strip())

        except Exception as e:
            self.issues.append(f"Could not read file: {str(e)}")

        except Exception as e:
            self.issues.append(f"Could not read file: {str(e)}")

        combined = "\n".join(text_fragments)
        
        # Use the filename as supplementary data
        name_lower = filename.lower()
        if "pharmacy" in name_lower or "license" in name_lower or "drug" in name_lower:
            print(f"[AI] Filename suggests a pharmacy-related document.")

        if len(combined) < 20:
            self.issues.append("Very little readable text found in document.")
            print("[AI] Warning: Very little text extracted.")

        print(f"[AI] Simulated OCR extracted {len(combined)} characters.")
        return combined

    # =========================================================================
    # STEP 2: Field Detection
    # =========================================================================
    def _detect_fields(self, text: str):
        """Use keyword matching + regex to find required fields."""
        text_lower = text.lower()
        lines = text.split("\n")

        # --- Pharmacy Name ---
        self.extracted_data["pharmacy_name"] = self._find_field_value(
            lines, text_lower, self.FIELD_KEYWORDS["pharmacy_name"]
        )

        # --- License Number ---
        license_val = self._find_field_value(
            lines, text_lower, self.FIELD_KEYWORDS["license_number"]
        )
        if not license_val:
            # Try to find any license-like pattern anywhere
            for pattern in self.LICENSE_PATTERNS:
                match = re.search(pattern, text)
                if match:
                    license_val = match.group(0)
                    break
        self.extracted_data["license_number"] = license_val

        # --- Issue Date ---
        issue_val = self._find_date_near_keyword(
            lines, text_lower, self.FIELD_KEYWORDS["issue_date"]
        )
        self.extracted_data["issue_date"] = issue_val

        # --- Expiry Date ---
        expiry_val = self._find_date_near_keyword(
            lines, text_lower, self.FIELD_KEYWORDS["expiry_date"]
        )
        self.extracted_data["expiry_date"] = expiry_val

        # --- Issuing Authority ---
        self.extracted_data["authority"] = self._find_field_value(
            lines, text_lower, self.FIELD_KEYWORDS["authority"]
        )

    def _find_field_value(self, lines: List[str], text_lower: str, keywords: List[str]) -> str:
        """Find the value associated with a keyword in the document text."""
        for keyword in keywords:
            if keyword in text_lower:
                # Find the line containing this keyword
                for line in lines:
                    if keyword in line.lower():
                        # Try to extract the value after : or =
                        for sep in [":", "=", "-", "–"]:
                            if sep in line:
                                parts = line.split(sep, 1)
                                if len(parts) == 2 and parts[1].strip():
                                    return parts[1].strip()
                        # If no separator, return the rest of the line after the keyword
                        idx = line.lower().index(keyword)
                        rest = line[idx + len(keyword):].strip()
                        if rest:
                            return rest
        return ""

    def _find_date_near_keyword(self, lines: List[str], text_lower: str, keywords: List[str]) -> str:
        """Find a date that appears near a keyword."""
        for keyword in keywords:
            if keyword in text_lower:
                for line in lines:
                    line_lower = line.lower()
                    if keyword in line_lower:
                        # Extract the part of the line AFTER the keyword
                        idx = line_lower.index(keyword)
                        rest_of_line = line[idx + len(keyword):]
                        
                        # Search for date pattern in the remainder of the line
                        for pattern in self.DATE_PATTERNS:
                            match = re.search(pattern, rest_of_line)
                            if match:
                                return match.group(0)
                        
                        # Fallback: Search the whole line if not found immediately after
                        for pattern in self.DATE_PATTERNS:
                            match = re.search(pattern, line)
                            if match:
                                return match.group(0)
                        
                        # Also check the next line if the date might be on a separate line
                        try:
                            line_idx = lines.index(line)
                            if line_idx + 1 < len(lines):
                                next_line = lines[line_idx+1]
                                for pattern in self.DATE_PATTERNS:
                                    match = re.search(pattern, next_line)
                                    if match:
                                        return match.group(0)
                        except (ValueError, IndexError):
                            pass
        return ""

    # =========================================================================
    # STEP 3: Field Validation
    # =========================================================================
    def _validate_fields(self):
        """Validate extracted fields for correctness."""
        data = self.extracted_data

        # Check pharmacy name
        if not data["pharmacy_name"]:
            self.issues.append("Pharmacy name not found or empty.")

        # Check license number format
        if not data["license_number"]:
            self.issues.append("License number not detected.")
        else:
            valid_format = False
            for pattern in self.LICENSE_PATTERNS:
                if re.fullmatch(pattern, data["license_number"]):
                    valid_format = True
                    break
            if not valid_format:
                self.issues.append(f"License number '{data['license_number']}' does not match known formats.")
                self.extracted_data["license_number"] = ""

        # Check dates
        issue_date = self._parse_date(data["issue_date"])
        expiry_date = self._parse_date(data["expiry_date"])

        if not data["issue_date"]:
            self.issues.append("Issue date not found.")
        if not data["expiry_date"]:
            self.issues.append("Expiry date not found.")

        if issue_date and expiry_date:
            if issue_date >= expiry_date:
                self.issues.append("Issue date is not before expiry date.")
            if expiry_date < date.today():
                self.issues.append("License has expired (expiry date is in the past).")
        elif expiry_date:
            if expiry_date < date.today():
                self.issues.append("License has expired (expiry date is in the past).")

        # Check authority
        if not data["authority"]:
            self.issues.append("Issuing authority not found.")

    def _parse_date(self, date_str: str) -> Optional[date]:
        """Attempt to parse a date string into a date object."""
        if not date_str:
            return None
        formats = [
            "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%Y/%m/%d",
            "%d %B %Y", "%B %d, %Y", "%B %d %Y",
            "%d %b %Y", "%b %d, %Y", "%b %d %Y",
            "%m/%Y", "%m-%Y"
        ]
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt).date()
            except ValueError:
                continue
        return None

    # =========================================================================
    # STEP 4: Authenticity Checks
    # =========================================================================
    def _check_authenticity(self, file_path: str, file_size: int, filename: str):
        """Perform heuristic authenticity checks on the document."""
        ext = os.path.splitext(filename)[1].lower()

        # Check 1: Suspiciously small files (likely not a real document)
        if file_size < 5 * 1024:  # Less than 5KB
            self.issues.append("Document file is unusually small — may not be a valid scan.")

        # Check 2: Image dimensions (for image files)
        if ext in [".jpg", ".jpeg", ".png"] and PIL_AVAILABLE:
            try:
                img = Image.open(file_path)
                width, height = img.size
                
                # Very small images are suspicious
                if width < 200 or height < 200:
                    self.issues.append("Image resolution too low for a scanned document.")
                
                # Check aspect ratio — license documents are typically portrait or landscape A4
                ratio = max(width, height) / max(min(width, height), 1)
                if ratio > 4.0:
                    self.issues.append("Unusual aspect ratio — document may be cropped or tampered.")
                
                # Check for mostly uniform color (blank/fake document)
                if img.mode in ("RGB", "L"):
                    extrema = img.getextrema()
                    if img.mode == "L":
                        diff = extrema[1] - extrema[0]
                    else:
                        diff = sum(e[1] - e[0] for e in extrema)
                    if diff < 30:
                        self.issues.append("Document appears mostly blank or uniform — possible forgery.")
                        
            except Exception as e:
                self.issues.append(f"Could not analyze image properties: {str(e)}")

        # Check 3: PDF basic checks
        if ext == ".pdf":
            try:
                with open(file_path, "rb") as f:
                    header = f.read(5)
                    if header != b"%PDF-":
                        self.issues.append("File does not appear to be a valid PDF.")
            except Exception:
                self.issues.append("Could not verify PDF file integrity.")

    # =========================================================================
    # STEP 5: Confidence Score
    # =========================================================================
    def _calculate_score(self, raw_text: str, file_size: int, filename: str) -> int:
        """
        Calculate a confidence score (0-100) based on:
        - Completeness: How many fields were found  (40 pts)
        - Clarity:      Text quality and file size   (30 pts)
        - Validity:     How many validation checks passed (30 pts)
        """
        score = 0

        # --- Completeness (40 pts) ---
        fields = self.extracted_data
        fields_found = sum(1 for v in fields.values() if v)
        total_fields = len(fields)
        score += int((fields_found / total_fields) * 40)

        # --- Clarity (30 pts) ---
        # Text length bonus
        if raw_text:
            text_len = len(raw_text.strip())
            if text_len > 500:
                score += 15
            elif text_len > 100:
                score += 10
            elif text_len > 20:
                score += 5

        # File size bonus (reasonable document size)
        if 10 * 1024 <= file_size <= 5 * 1024 * 1024:
            score += 15
        elif 5 * 1024 <= file_size < 10 * 1024:
            score += 8
        else:
            score += 2

        # --- Validity (30 pts) ---
        # Start with full marks, deduct for each issue
        validity_score = 30
        critical_issues = [
            "License has expired",
            "Issue date is not before expiry date",
            "not a valid PDF",
            "mostly blank or uniform",
            "License number not detected",
        ]
        
        # --- Negative Keyword Check (Critical) ---
        text_lower = raw_text.lower()
        filename_lower = filename.lower()
        
        for keyword in self.FIELD_KEYWORDS["non_license_titles"]:
            # Use regex for whole-word matching to avoid false positives (e.g. 'cv' in 'government')
            pattern = rf"\b{re.escape(keyword)}\b"
            if re.search(pattern, text_lower) or re.search(pattern, filename_lower):
                print(f"[AI] Negative keyword detected: '{keyword}'")
                self.issues.append(f"non-license document detected: appears to be a '{keyword}' instead of a pharmacy license.")
                validity_score -= 25
                break

        for issue in self.issues:
            for critical in critical_issues:
                if critical in issue:
                    validity_score -= 10
                    break
            else:
                validity_score -= 3  # Minor issue

        # --- Final Zero-Trust Guard ---
        if not raw_text.strip() or len(raw_text.strip()) < 10:
            print("[AI] Zero-Trust Guard: No text found. Forcing score to 0.")
            if not PIL_AVAILABLE or not TESSERACT_AVAILABLE:
                self.issues.append("AI Engine Offline: OCR dependencies not installed on server.")
            else:
                self.issues.append("Document Unreadable: AI could not extract enough text. Please ensure the scan is clear and high resolution.")
            return 0

        score += max(0, validity_score)

        return min(100, max(0, score))

    # =========================================================================
    # STEP 6: Final Decision
    # =========================================================================
    def _make_decision(self, score: int) -> str:
        """
        APPROVED → if all checks pass and confidence > 85
        REVIEW   → if partially valid or unclear
        REJECTED → if critical fields missing or invalid
        """
        critical_issues = [
            "License has expired",
            "not a valid PDF",
            "mostly blank or uniform",
            "possible forgery",
            "non-license document detected",
            "License number not detected",
            "does not match known formats",
        ]
        
        has_critical = any(
            any(crit in issue for crit in critical_issues)
            for issue in self.issues
        )

        if has_critical:
            print("[AI] Found critical issues, forcing REJECTED")
            return "REJECTED"
        
        if score >= 85:
            print(f"[AI] Score {score} >= 85, status: APPROVED")
            return "APPROVED"
        elif score >= 50:
            print(f"[AI] Score {score} >= 50, status: REVIEW")
            return "REVIEW"
        else:
            print(f"[AI] Score {score} < 50, status: REJECTED")
            return "REJECTED"
