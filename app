# -*- coding: utf-8 -*-
"""
AI-Powered Self-Assessment Report (SAR) Generator
This Streamlit application helps generate SAR sections based on the HA Standard 5th Edition.
Users can select a specific SAR item, upload relevant documents, and provide additional context.
The AI will then synthesize the information and generate a report following the required structure.
"""

import streamlit as st
import io
import os
from pypdf import PdfReader
from docx import Document
from google import genai

# --- Page Configuration ---
st.set_page_config(
    page_title="AI SAR Generator (HA Standard)",
    page_icon="📝",
    layout="wide",
    initial_sidebar_state="expanded"
)

# --- Hardcoded Knowledge Base & SAR Items ---
SAR_ITEMS = {
    # ... (รายการเดิมทั้ง 1–82 คงไว้เหมือนเดิม)
    1: "I-1.1ก(1)(2)(3) การชี้นำองค์กรโดยผู้นำระดับสูง",
    2: "I-1.1ข การสื่อสาร สร้างความผูกพันโดยผู้นำ**",
    # (ตัดทอนในตัวอย่าง)
    82: "III-6 การดูแลต่อเนื่อง**"
}

KNOWLEDGE_BASE = """
- HA Standard 5th Edition: ...
- SPA Manuals (Part I, II, III): ...
- 3P Framework (Purpose-Process-Performance): ...
- SAR Structure: ...
"""

# --- Helper Functions ---
def extract_text_from_pdf(file):
    try:
        pdf_reader = PdfReader(file)
        text = ""
        for page in pdf_reader.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
        return text
    except Exception as e:
        st.error(f"Error reading PDF file {file.name}: {e}")
        return ""

def extract_text_from_docx(file):
    try:
        doc = Document(io.BytesIO(file.read()))
        text = "\n".join([para.text for para in doc.paragraphs])
        return text
    except Exception as e:
        st.error(f"Error reading DOCX file {file.name}: {e}")
        return ""

def get_all_input_text(uploaded_files, additional_context):
    full_text = ""
    if not uploaded_files and not additional_context:
        return "", False

    if uploaded_files:
        for file in uploaded_files:
            full_text += f"--- START OF FILE: {file.name} ---\n\n"
            file_type = file.type
            if "pdf" in file_type:
                full_text += extract_text_from_pdf(file)
            elif "wordprocessingml" in file_type or "officedocument" in file_type:
                full_text += extract_text_from_docx(file)
            else:
                st.warning(f"Unsupported file type: {file.name}. Skipping.")
            full_text += f"\n\n--- END OF FILE: {file.name} ---\n\n"

    if additional_context:
        full_text += f"--- START OF ADDITIONAL USER NOTES ---\n\n"
        full_text += additional_context
        full_text += f"\n\n--- END OF ADDITIONAL USER NOTES ---\n\n"

    return full_text, True

def generate_sar_section(api_key, sar_item, context_data):
    """Generates a single SAR section using the Gemini API (new Google GenAI SDK)."""
    try:
        client = genai.Client(api_key=api_key)

        prompt = f"""
        คุณคือผู้เชี่ยวชาญด้านการรับรองคุณภาพโรงพยาบาลในประเทศไทย (Hospital Accreditation) ที่มีความสามารถในการเขียนรายงานประเมินตนเอง (Self-Assessment Report - SAR) ตามมาตรฐาน HA ฉบับที่ 5

        **ภารกิจของคุณ:**
        เขียนรายงาน SAR สำหรับหัวข้อต่อไปนี้:
        **{sar_item}**

        **ฐานความรู้ของคุณ:**
        {KNOWLEDGE_BASE}

        **ข้อมูลนำเข้า (จากไฟล์และข้อความที่ผู้ใช้อัปโหลด):**
        ```
        {context_data}
        ```

        **คำสั่ง:**
        1) วิเคราะห์ข้อมูลนำเข้า
        2) สังเคราะห์ตามโครงสร้าง 4 ส่วน (i. บริบท ii. ประเด็นการพัฒนา/แผน iii. ผลการพัฒนาที่โดดเด่น iv. ผลลัพธ์)
        3) ใช้หลัก 3P (Purpose-Process-Performance)
        4) อ้างอิงด้วย [cite: ชื่อไฟล์]
        5) จบส่วน "iv. ผลลัพธ์" ด้วยหมายเหตุ KPI 3–5 ปี
        **สำคัญ:** อิงเฉพาะข้อมูลที่ให้มา ห้ามสร้างข้อมูลเอง
        """

        resp = client.models.generate_content(
            model="gemini-2.5-flash",  # หรือ "gemini-2.5-flash-lite"
            contents=prompt
        )
        return getattr(resp, "text", None) or getattr(resp, "output_text", None)

    except Exception as e:
        st.error(f"An error occurred while calling the Gemini API: {e}")
        st.error("เคล็ดลับ: ตรวจสอบ API Key/สิทธิ์ และชื่อโมเดลว่ารองรับ generateContent")
        return None

# --- Main Application Logic ---
st.title("📝 AI Self-Assessment Report (SAR) Generator")
st.markdown("เครื่องมือช่วยสร้างรายงานประเมินตนเองตามมาตรฐาน HA ฉบับที่ 5")
st.markdown("---")

# --- Get API Key (Render env var first, fallback to secrets for local dev) ---
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    try:
        GEMINI_API_KEY = st.secrets["GEMINI_API_KEY"]
    except Exception:
        st.error("⚠️ ยังไม่ได้ตั้งค่า API Key!")
        st.info(
            """
            **บน Render:** ไปที่ Service → Settings → Environment → เพิ่มตัวแปร:
            - Key: `GEMINI_API_KEY`
            - Value: ใส่ Gemini API Key ของคุณ

            **รันบนเครื่อง (ตัวเลือกเสริม):** สร้าง `.streamlit/secrets.toml`
            แล้วใส่ `GEMINI_API_KEY = "YOUR_API_KEY_HERE"`
            """
        )
        st.stop()

# --- Sidebar for Inputs ---
with st.sidebar:
    st.header("1. ป้อนข้อมูล")
    st.success("API Key ถูกโหลดเรียบร้อยแล้ว (ENV/secrets)")

    sar_options = [f"{key}. {value}" for key, value in SAR_ITEMS.items() if key <= 82]

    selected_option_str = st.selectbox(
        "เลือกหัวข้อ SAR ที่ต้องการทำ (1-82)",
        options=sar_options,
        index=None,
        placeholder="เลือกหัวข้อ..."
    )

    uploaded_files = st.file_uploader(
        "อัปโหลดไฟล์ที่เกี่ยวข้อง (PDF, DOCX)",
        type=["pdf", "docx"],
        accept_multiple_files=True
    )

    additional_context = st.text_area(
        "เขียนข้อมูลหรือบริบทเพิ่มเติม (ถ้ามี)",
        height=150,
        placeholder="เช่น ประเด็นที่ต้องการเน้นเป็นพิเศษ, ข้อมูลที่ไม่มีในเอกสาร..."
    )

    generate_button = st.button("🚀 สร้างรายงาน SAR", use_container_width=True, type="primary")

# --- Main Content Area for Output ---
st.header("2. ผลลัพธ์ (AI-Generated SAR)")

if 'report_output' not in st.session_state:
    st.session_state.report_output = ""

if generate_button:
    if not selected_option_str:
        st.error("กรุณาเลือกหัวข้อ SAR ที่ต้องการทำ")
    elif not uploaded_files and not additional_context:
        st.error("กรุณาอัปโหลดไฟล์อย่างน้อย 1 ไฟล์ หรือใส่ข้อมูลเพิ่มเติม")
    else:
        with st.spinner("⏳ AI กำลังอ่านไฟล์และเรียบเรียงรายงาน..."):
            context_data, files_ok = get_all_input_text(uploaded_files, additional_context)

            if files_ok:
                generated_report = generate_sar_section(GEMINI_API_KEY, selected_option_str, context_data)
                if generated_report:
                    st.session_state.report_output = generated_report
                else:
                    st.session_state.report_output = ""
                    st.error("ไม่สามารถสร้างรายงานได้ กรุณาตรวจสอบข้อผิดพลาดและลองใหม่")
            else:
                st.error("ไม่สามารถดึงข้อมูลจากไฟล์ที่อัปโหลดได้ กรุณาตรวจสอบไฟล์อีกครั้ง")

if st.session_state.report_output:
    st.markdown(st.session_state.report_output)
else:
    st.info("กรุณาเลือกหัวข้อ, อัปโหลดไฟล์, และกดปุ่ม 'สร้างรายงาน SAR' เพื่อเริ่มต้น")
